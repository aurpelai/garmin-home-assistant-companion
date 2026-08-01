import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Networking core. Wraps Communications.makeWebRequest with Bearer auth and
// JSON, and exposes the operations the UI needs:
//   - register:       POST /api/mobile_app/registrations, once per HA instance,
//     to obtain the webhook_id fetchHomeState rides over.
//   - fetchHomeState: POST /api/webhook/{webhook_id} rendering each area's
//     entities AND their states, names and sensor readings (a plain GET
//     /api/states returns every entity in the instance and blows past Connect
//     IQ's HTTP response-size limit, so everything rides along in the
//     template instead). Recovers once from an invalidated webhook_id by
//     re-registering and retrying.
//   - toggleLight:    POST /api/services/light/toggle
//
// Connect IQ is single-threaded and callback-based: every method takes a
// Lang.Method callback invoked with the parsed result. Callers sequence
// dependent requests by chaining in their callbacks.
class HaClient {

    // Fixed device identity for the mobile_app registration. This app cannot
    // introspect real device info (model, OS) in scope for this spec, so
    // every install registers under the same constants.
    private const DEVICE_ID = "garmin_ha_companion";
    private const APP_ID = "garmin_home_assistant";
    private const APP_NAME = "HA Companion";
    private const APP_VERSION = "1";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    // HTTP/comm codes HA/Connect IQ produce for an invalid or unknown
    // webhook_id: -400 is Connect IQ's own "invalid http body" comm code (HA
    // sends no body back for a dead webhook), 404 is HA's when the id is
    // simply gone (instance rebuilt, app uninstalled and reinstalled, etc).
    private const INVALID_WEBHOOK_CODES = [
        Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE,
        404
    ];

    // Deliberately not piped through `| tojson`: the webhook returns
    // application/json and parses the body itself, so an unwrapped dict arrives
    // as an object; `| tojson` would instead deliver an escaped JSON string.
    //
    // Deliberately backslash-free: we filter entities with `.startswith(...)`
    // instead of a regex like select('match','^light\.'). A backslash in this
    // string would be sent unescaped by the Connect IQ JSON serializer, producing
    // an invalid JSON escape and a 400 "Invalid JSON specified" from HA.
    private const HOME_STATE_TEMPLATE =
        "{% set ns = namespace(lightsByArea={}, sensorsByArea={}, states={}, names={}, " +
            "groups={}, available={}, readings={}, kinds={}, lights=[], sensors=[], floors=[]) %}" +
        "{% for a in areas() %}" +

        // Hidden entities are rejected once, here, so every walk below inherits
        // the exclusion and so does every entity kind added later. Requires Home
        // Assistant 2023.4. Materialized with `| list` because reject() yields a
        // generator, which the per-kind walks would find exhausted.
        "{% set visible = area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% set ns.lights = [] %}" +
        "{% set ns.sensors = [] %}" +

        // A light group is a light.* entity whose `entity_id` attribute holds its
        // member ids; a plain light has no such attribute. A group's count is the
        // members surviving the same hidden-entity test, so the number a row
        // shows cannot contradict the entities the app will list, and a group
        // left with none drops out alongside them. `expand` recurses to leaf
        // entities, so hiding an intermediate group hides that group's own row
        // without hiding the lights beneath it.
        //
        // `states[e].name` is Home Assistant's own display name: the user-set
        // friendly name if any, else its built-in fallback. It is not guaranteed
        // — an area-assigned entity carrying no state object yields no name and
        // fails the whole render, not just its own row. The model's bare-id
        // fallback does not rescue that.
        "{% for e in visible %}" +
        "{% if e.startswith('light.') %}" +
        "{% set isGroup = state_attr(e, 'entity_id') is not none %}" +
        "{% set visibleMembers = expand(e) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| list | count if isGroup else 0 %}" +
        "{% if not isGroup or visibleMembers > 0 %}" +
        "{% set ns.lights = ns.lights + [e] %}" +
        "{% set ns.states = dict(ns.states, **{e: is_state(e, 'on')}) %}" +
        "{% set ns.names = dict(ns.names, **{e: states[e].name}) %}" +
        "{% set ns.available = dict(ns.available, **{e: not is_state(e, 'unavailable')}) %}" +
        "{% if isGroup %}" +
        "{% set ns.groups = dict(ns.groups, **{e: visibleMembers}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +

        // Looping the kinds outside the entity loop is what makes each area's
        // sensor list arrive already grouped by kind, so the watch never sorts;
        // within a kind the order is Home Assistant's own.
        //
        // A reading is `states(e, true, true)`: HA's own display precision and
        // unit, as a string, so the watch never parses, rounds or appends a unit
        // and cannot disagree with the user's dashboard. Needs HA 2023.3.
        //
        // `unknown` folds into unavailable, because never-reported and
        // currently-dead read the same to someone glancing at a watch.
        "{% for kind in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% for e in visible %}" +
        "{% if e.startswith('sensor.') and state_attr(e, 'device_class') == kind %}" +
        "{% set ns.sensors = ns.sensors + [e] %}" +
        "{% set ns.readings = dict(ns.readings, **{e: dict(" +
            "value=states(e) | float, display=states(e, true, true), " +
            "unit=state_attr(e, 'unit_of_measurement'))}) %}" +
        "{% set ns.names = dict(ns.names, **{e: states[e].name}) %}" +
        "{% set ns.available = dict(ns.available, " +
            "**{e: not is_state(e, 'unavailable') and not is_state(e, 'unknown')}) %}" +
        "{% set ns.kinds = dict(ns.kinds, **{e: kind}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +

        // Emit the area only if it holds at least one entity we support (a
        // light or a sensor). An area whose only entities are kinds this version
        // doesn't render (e.g. a garage of car entities) is left out entirely.
        "{% if ns.lights or ns.sensors %}" +
        "{% set ns.lightsByArea = dict(ns.lightsByArea, **{area_name(a): ns.lights}) %}" +
        "{% set ns.sensorsByArea = dict(ns.sensorsByArea, **{area_name(a): ns.sensors}) %}" +
        "{% endif %}" +
        "{% endfor %}" +

        // Accumulated on `ns` (not a plain `{% set %}`): a variable assigned
        // inside a Jinja for-loop is scoped to the iteration and never escapes,
        // so a plain accumulator would come out empty.
        "{% for f in floors() %}" +
        "{% set floorAreas = floor_areas(f) | map('area_name') | list %}" +
        "{% set ns.floors = ns.floors + [dict(name=floor_name(f), areas=floorAreas)] %}" +
        "{% endfor %}" +

        "{{ dict(areas=ns.lightsByArea, sensors=ns.sensorsByArea, states=ns.states, " +
            "groups=ns.groups, readings=ns.readings, names=ns.names, " +
            "available=ns.available, floors=ns.floors, kinds=ns.kinds) }}";

    function initialize() {}

    // --- public API ---

    // Fetches the rendered home state over the registered webhook, recovering
    // once from an invalidated webhook_id (see FetchRecoveryHandler) before
    // surfacing failure normally.
    function fetchHomeState(callback as Method) as Void {
        new FetchRecoveryHandler(self, callback).attempt();
    }

    // Registers the app with HA and, on success, caches the returned
    // webhook_id and the URL it was registered against — every caller
    // benefits from the cache without repeating the bookkeeping.
    function register(callback as Method) as Void {
        var body = {
            "device_id" => DEVICE_ID,
            "app_id" => APP_ID,
            "app_name" => APP_NAME,
            "app_version" => APP_VERSION,
            "device_name" => DEVICE_NAME,
            "manufacturer" => MANUFACTURER,
            "model" => MODEL,
            "os_name" => OS_NAME,
            "os_version" => OS_VERSION,
            "supports_encryption" => false,
            "app_data" => {}
        };
        post("/api/mobile_app/registrations", body,
             new ResponseHandler(new RegisterCacheHandler(callback).method(:onRegistered), :onRegister));
    }

    function toggleLight(entityId as String, callback as Method) as Void {
        post("/api/services/light/toggle", { "entity_id" => entityId },
             new ResponseHandler(callback, :onService));
    }

    // Single-attempt webhook POST, with no recovery of its own — called
    // directly by fetchHomeState's first try and by FetchRecoveryHandler's
    // one retry. Kept separate from fetchHomeState so FakeHaClient can
    // override the public entry point without inheriting real transport.
    function fetchOnce(callback as Method) as Void {
        var webhookId = Settings.getWebhookId();
        if (webhookId == null) {
            callback.invoke(null, 404);
            return;
        }
        var body = { "type" => "render_template", "data" => { "home" => { "template" => HOME_STATE_TEMPLATE } } };
        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, :onTemplate));
    }

    // Whether a fetch failure code signals an invalid or unknown webhook_id
    // (as opposed to e.g. a network drop) — the case FetchRecoveryHandler
    // recovers from by re-registering.
    function isInvalidWebhookCode(code as Number) as Boolean {
        for (var index = 0; index < INVALID_WEBHOOK_CODES.size(); index++) {
            if (INVALID_WEBHOOK_CODES[index] == code) {
                return true;
            }
        }
        return false;
    }

    // --- transport ---

    private function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        Communications.makeWebRequest(
            Settings.getBaseUrl() + path, body as Dictionary<Object, Object>,
            buildOptions(Communications.HTTP_REQUEST_METHOD_POST),
            handler.method(:onResponse));
    }

    // Typed to the shape makeWebRequest expects for its options argument, so it
    // matches under strict type checking (-l 3).
    private function buildOptions(httpMethod as Communications.HttpRequestMethod) as {
            :method as Communications.HttpRequestMethod,
            :headers as Dictionary,
            :responseType as Communications.HttpResponseContentType } {
        return {
            :method => httpMethod,
            :headers => {
                "Authorization" => "Bearer " + Settings.getToken(),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }
}

// Caches a successful registration's webhook_id (and the URL it was
// registered against) before forwarding the normalized result to the
// caller's own callback.
class RegisterCacheHandler {
    private var _callback as Method;

    function initialize(callback as Method) {
        _callback = callback;
    }

    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
        if (error == null) {
            Settings.setWebhookId(webhookId as String);
            Settings.setRegisteredUrl(Settings.getBaseUrl());
        }
        _callback.invoke(webhookId, error);
    }
}

// Orchestrates fetchHomeState's one-shot recovery: try the webhook once, and
// on a code signalling an invalidated webhook_id, clear it, register a fresh
// one, and retry exactly once more. Any other failure (or a second failure
// after the retry) surfaces to the caller unchanged — there is no recursion,
// so this can never loop.
class FetchRecoveryHandler {
    private var _client as HaClient;
    private var _callback as Method;

    function initialize(client as HaClient, callback as Method) {
        _client = client;
        _callback = callback;
    }

    function attempt() as Void {
        _client.fetchOnce(method(:onFirstAttempt));
    }

    function onFirstAttempt(state as HomeState or Null, error as Number or Null) as Void {
        if (error == null || !_client.isInvalidWebhookCode(error as Number)) {
            _callback.invoke(state, error);
            return;
        }
        Settings.clearWebhookId();
        _client.register(method(:onRegistered));
    }

    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
        if (error != null) {
            _callback.invoke(null, error);
            return;
        }
        _client.fetchOnce(method(:onRetryAttempt));
    }

    function onRetryAttempt(state as HomeState or Null, error as Number or Null) as Void {
        _callback.invoke(state, error);
    }
}

// Adapts a raw makeWebRequest callback (code, data) into a typed result handed
// to the caller's callback. `kind` selects how the body is interpreted.
class ResponseHandler {
    private var _callback as Method;
    private var _kind as Symbol;

    function initialize(callback as Method, kind as Symbol) {
        _callback = callback;
        _kind = kind;
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200) {
            // Surface the HTTP/comm code and any HA error body in the console to
            // aid debugging (e.g. 400 "Invalid JSON specified", 401 auth).
            System.println("HA request failed: kind=" + _kind + " code=" + code + " body=" + data);
            _callback.invoke(null, code);
            return;
        }
        switch (_kind) {
            case :onTemplate:
                // The webhook response is {"home": {...}} — the nested value is
                // the actual home-state dictionary fromTemplateData expects.
                var home = (data instanceof Dictionary) ? data.get("home") : null;
                _callback.invoke(HomeState.fromTemplateData(home as Dictionary or String or Null), null);
                break;
            case :onRegister:
                var webhookId = (data instanceof Dictionary) ? data.get("webhook_id") : null;
                if (webhookId instanceof Lang.String) {
                    _callback.invoke(webhookId, null);
                } else {
                    // A 2xx with no usable webhook_id is a bad body, not success:
                    // report the invalid-body code so the error channel never
                    // carries a success code.
                    _callback.invoke(null, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
                }
                break;
            case :onService:
                _callback.invoke(true, null);
                break;
        }
    }
}
