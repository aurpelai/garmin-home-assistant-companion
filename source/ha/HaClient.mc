import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Everything rides one webhook template render because a plain GET /api/states
// returns every entity in the instance and blows past Connect IQ's HTTP
// response-size limit.
class HaClient {

    // The device can't introspect its real model/OS, so every install registers
    // under these same constants.
    private const DEVICE_ID = "garmin_ha_companion";
    private const APP_ID = "garmin_home_assistant";
    private const APP_NAME = "HA Companion";
    private const APP_VERSION = "1";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    // A dead webhook_id shows up as one of these: -400 because HA sends no body
    // (Connect IQ reports that as invalid-http-body), or 404 when the id is gone.
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

        // `| list` is load-bearing: reject() yields a generator that the second
        // (per-kind) walk below would find already exhausted. Needs HA 2023.4.
        "{% set visible = area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% set ns.lights = [] %}" +
        "{% set ns.sensors = [] %}" +

        // An area-assigned entity with no state object yields no name from
        // `states[e].name` and fails the whole render, not just its own row.
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

        // `states(e, true, true)` keeps HA's own display precision and unit as a
        // string, so the watch never reparses or rounds and can't disagree with
        // the user's dashboard. Needs HA 2023.3.
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

        "{% if ns.lights or ns.sensors %}" +
        "{% set ns.lightsByArea = dict(ns.lightsByArea, **{area_name(a): ns.lights}) %}" +
        "{% set ns.sensorsByArea = dict(ns.sensorsByArea, **{area_name(a): ns.sensors}) %}" +
        "{% endif %}" +
        "{% endfor %}" +

        // On `ns` because a plain `{% set %}` inside a Jinja for-loop is scoped
        // to the iteration and wouldn't escape.
        "{% for f in floors() %}" +
        "{% set floorAreas = floor_areas(f) | map('area_name') | list %}" +
        "{% set ns.floors = ns.floors + [dict(name=floor_name(f), areas=floorAreas)] %}" +
        "{% endfor %}" +

        "{{ dict(areas=ns.lightsByArea, sensors=ns.sensorsByArea, states=ns.states, " +
            "groups=ns.groups, readings=ns.readings, names=ns.names, " +
            "available=ns.available, floors=ns.floors, kinds=ns.kinds) }}";

    function initialize() {}

    function fetchHomeState(callback as Method) as Void {
        new FetchRecoveryHandler(self, callback).attempt();
    }

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

    function fetchOnce(callback as Method) as Void {
        var webhookId = Settings.getWebhookId();
        if (webhookId == null) {
            callback.invoke(null, 404);
            return;
        }
        var body = { "type" => "render_template", "data" => { "home" => { "template" => HOME_STATE_TEMPLATE } } };
        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, :onTemplate));
    }

    function isInvalidWebhookCode(code as Number) as Boolean {
        for (var index = 0; index < INVALID_WEBHOOK_CODES.size(); index++) {
            if (INVALID_WEBHOOK_CODES[index] == code) {
                return true;
            }
        }
        return false;
    }

    private function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        Communications.makeWebRequest(
            Settings.getBaseUrl() + path, body as Dictionary<Object, Object>,
            buildOptions(Communications.HTTP_REQUEST_METHOD_POST),
            handler.method(:onResponse));
    }

    // The verbose return type is spelled out to satisfy strict type checking (-l 3).
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

// One-shot recovery: no path re-enters attempt(), so a persistently invalid
// webhook_id can never loop.
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

class ResponseHandler {
    private var _callback as Method;
    private var _kind as Symbol;

    function initialize(callback as Method, kind as Symbol) {
        _callback = callback;
        _kind = kind;
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200) {
            System.println("HA request failed: kind=" + _kind + " code=" + code + " body=" + data);
            _callback.invoke(null, code);
            return;
        }
        switch (_kind) {
            case :onTemplate:
                var home = (data instanceof Dictionary) ? data.get("home") : null;
                _callback.invoke(HomeState.fromTemplateData(home as Dictionary or String or Null), null);
                break;
            case :onRegister:
                var webhookId = (data instanceof Dictionary) ? data.get("webhook_id") : null;
                if (webhookId instanceof Lang.String) {
                    _callback.invoke(webhookId, null);
                } else {
                    // Report an error code, not the 200: a body without a usable
                    // webhook_id is a failure the error channel must carry.
                    _callback.invoke(null, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
                }
                break;
            case :onService:
                _callback.invoke(true, null);
                break;
        }
    }
}
