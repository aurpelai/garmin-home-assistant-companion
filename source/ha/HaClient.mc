import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Networking core. Wraps Communications.makeWebRequest with Bearer auth and
// JSON, and exposes the operations the UI needs:
//   - fetchHomeState: one POST /api/template call rendering each area's entities
//     AND their states, names and sensor readings (a plain GET /api/states
//     returns every entity in the instance and blows past Connect IQ's HTTP
//     response-size limit, so everything rides along in the template instead).
//   - toggleLight:  POST /api/services/light/toggle
//
// Connect IQ is single-threaded and callback-based: every method takes a
// Lang.Method callback invoked with the parsed result. Callers sequence
// dependent requests by chaining in their callbacks.
class HaClient {

    // Jinja rendered by HA. Must end in `| tojson` — /api/template returns plain
    // text, so without it the body would be a Python-repr dict, not valid JSON.
    //
    // Renders { "areas":     { areaName: [lightId, ...] },
    //           "sensors":   { areaName: [sensorId, ...] },
    //           "states":    { lightId: bool },
    //           "groups":    { lightId: memberCount },
    //           "readings":  { sensorId: "24.6 °C" },
    //           "names":     { entityId: "Display Name" },
    //           "available": { entityId: bool } }.
    //
    // The light walk records each light's on/off state via is_state (a real JSON
    // boolean, not a string), its name, its availability, and — for light groups —
    // how many lights the group controls. A light group is a light.* entity whose
    // `entity_id` state attribute is defined (it holds the group's member ids); a
    // plain light has no such attribute, so `state_attr(e, 'entity_id')` is none.
    // "groups" maps each group id to how many of its member lights survive the
    // same hidden-entity filter, counted server-side into a scalar so member
    // lists never reach the watch. Filtering the members and not just the group
    // is what keeps the number a row shows from contradicting the entities the
    // app is willing to show; a group whose members are all hidden drops out
    // along with them. `expand` recurses through nested groups and yields leaf
    // entities, so hiding an intermediate group hides that group's own row
    // without hiding the lights beneath it. Entities with no area are never
    // visited by areas()/area_entities() and are thus naturally excluded.
    //
    // Looping the sensor kinds outside the entity loop is what makes each area's
    // sensor list arrive already grouped by kind, so the watch never sorts it;
    // within a kind the order is Home Assistant's own area order.
    // "readings" holds `states(e, true, true)` — the state rendered with HA's own
    // display precision and unit, as a string, so the watch never parses, rounds
    // or appends a unit and cannot disagree with the user's dashboard. That call
    // needs Home Assistant 2023.3 or newer, below the app's documented floor.
    //
    // A sensor reporting `unknown` is marked unavailable alongside one reporting
    // `unavailable`: never-reported and currently-dead are the same thing to a
    // reader, and folding them together keeps the client to a single rule.
    //
    // The filtered entity list is materialized with `| list` because reject()
    // yields a generator, which the per-kind walks would find exhausted.
    //
    // An area is emitted when it holds at least one visible entity the app can
    // show, of either kind — so a sensor-only area appears, carrying an empty
    // light list.
    //
    // The name is `states[e].name` — Home Assistant's own display name: the
    // user-set friendly name if any, else HA's built-in fallback (the object id
    // with underscores as spaces, lower case). It is not a guaranteed value: an
    // area-assigned entity carrying no state object at all yields no name here
    // and takes the whole `| tojson` down with it, failing the request rather
    // than one row. The model's bare-id fallback does not rescue that.
    //
    // Deliberately backslash-free: we filter entities with `.startswith(...)`
    // instead of a regex like select('match','^light\.'). A backslash in this
    // string would be sent unescaped by the Connect IQ JSON serializer, producing
    // an invalid JSON escape and a 400 "Invalid JSON specified" from HA.
    //
    // `is_hidden_entity` requires Home Assistant 2023.4 or newer. Keep the reject
    // in the filtered list every walk reads: every entity kind added later
    // inherits the exclusion for free.
    private const HOME_STATE_TEMPLATE =
        "{% set ns = namespace(lightsByArea={}, sensorsByArea={}, states={}, names={}, " +
            "groups={}, available={}, readings={}, lights=[], sensors=[]) %}" +
        "{% for a in areas() %}" +
        "{% set visible = area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% set ns.lights = [] %}" +
        "{% set ns.sensors = [] %}" +
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
        "{% for kind in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% for e in visible %}" +
        "{% if e.startswith('sensor.') and state_attr(e, 'device_class') == kind %}" +
        "{% set ns.sensors = ns.sensors + [e] %}" +
        "{% set ns.readings = dict(ns.readings, **{e: states(e, true, true)}) %}" +
        "{% set ns.names = dict(ns.names, **{e: states[e].name}) %}" +
        "{% set ns.available = dict(ns.available, " +
            "**{e: not is_state(e, 'unavailable') and not is_state(e, 'unknown')}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{% if ns.lights or ns.sensors %}" +
        "{% set ns.lightsByArea = dict(ns.lightsByArea, **{area_name(a): ns.lights}) %}" +
        "{% set ns.sensorsByArea = dict(ns.sensorsByArea, **{area_name(a): ns.sensors}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{{ dict(areas=ns.lightsByArea, sensors=ns.sensorsByArea, states=ns.states, " +
            "groups=ns.groups, readings=ns.readings, names=ns.names, " +
            "available=ns.available) | tojson }}";

    function initialize() {}

    // --- public API ---

    function fetchHomeState(callback as Method) as Void {
        var body = { "template" => HOME_STATE_TEMPLATE };
        post("/api/template", body, new ResponseHandler(callback, :onTemplate));
    }

    function toggleLight(entityId as String, callback as Method) as Void {
        post("/api/services/light/toggle", { "entity_id" => entityId },
             new ResponseHandler(callback, :onService));
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
                // /api/template returns text/plain containing JSON. If Connect IQ
                // handed us an unparsed String instead of a Dictionary, log it so
                // the empty case is diagnosable.
                if (data instanceof Lang.String) {
                    System.println("Template returned unparsed String: " + data);
                }
                _callback.invoke(HomeState.fromTemplateData(data), null);
                break;
            case :onService:
                _callback.invoke(true, null);
                break;
        }
    }
}
