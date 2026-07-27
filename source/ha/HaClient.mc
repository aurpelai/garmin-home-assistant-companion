import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Networking core. Wraps Communications.makeWebRequest with Bearer auth and
// JSON, and exposes the operations the UI needs:
//   - fetchLightState: one POST /api/template call rendering both the
//     areas→lights join AND each light's on/off state (a plain GET /api/states
//     returns every entity in the instance and blows past Connect IQ's HTTP
//     response-size limit, so states ride along in the template instead).
//   - toggleLight:  POST /api/services/light/toggle
//
// Connect IQ is single-threaded and callback-based: every method takes a
// Lang.Method callback invoked with the parsed result. Callers sequence
// dependent requests by chaining in their callbacks.
class HaClient {

    // Jinja rendered by HA. Must end in `| tojson` — /api/template returns plain
    // text, so without it the body would be a Python-repr dict, not valid JSON.
    //
    // Renders { "areas": { areaName: [lightId, ...] }, "states": { lightId: bool },
    //          "names": { lightId: "Display Name" }, "groups": { lightId: memberCount },
    //          "available": { lightId: bool } }.
    // The single inner area-walk collects an area's lights, records each light's
    // on/off state via is_state (a real JSON boolean, not a string), records the
    // name Home Assistant shows for each light, records how many lights each
    // light group controls, and records each light's availability via
    // `not is_state(e, 'unavailable')` (a real JSON boolean). A light group is a
    // light.* entity whose `entity_id` state attribute is defined (it holds the
    // group's member ids); a plain light has no such attribute, so
    // `state_attr(e, 'entity_id')` is none. "groups" maps each group id to its
    // member count — `expand(e) | count`, the number of leaf
    // entities the group expands to (recursing through any nested groups), computed
    // server-side into a scalar so member lists never reach the watch. Lights with
    // no area are never visited by areas()/area_entities() and are thus naturally
    // excluded.
    //
    // The name is `states[e].name` — Home Assistant's own display name: the
    // user-set friendly name if any, else HA's built-in fallback (the object id
    // with underscores as spaces, lower case). This is never none, so a name is
    // emitted for every light; the model's bare-id fallback covers only a
    // server-contract violation. (This is the expression to confirm against a
    // live instance, per the spec's verification note.)
    //
    // Deliberately backslash-free: we filter light entities with
    // `.startswith('light.')` instead of a regex like select('match','^light\.').
    // A backslash in this string would be sent unescaped by the Connect IQ JSON
    // serializer, producing an invalid JSON escape and a 400 "Invalid JSON
    // specified" from HA.
    private const LIGHT_STATE_TEMPLATE =
        "{% set ns = namespace(m={}, s={}, n={}, groups={}, avail={}) %}" +
        "{% for a in areas() %}" +
        "{% set ns.lights = [] %}" +
        "{% for e in area_entities(a) %}" +
        "{% if e.startswith('light.') %}" +
        "{% if state_attr(e, 'entity_id') is none or expand(e) | count > 0 %}" +
        "{% set ns.lights = ns.lights + [e] %}" +
        "{% set ns.s = dict(ns.s, **{e: is_state(e, 'on')}) %}" +
        "{% set ns.n = dict(ns.n, **{e: states[e].name}) %}" +
        "{% set ns.avail = dict(ns.avail, **{e: not is_state(e, 'unavailable')}) %}" +
        "{% if state_attr(e, 'entity_id') is not none %}" +
        "{% set ns.groups = dict(ns.groups, **{e: expand(e) | count}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% if ns.lights | count > 0 %}" +
        "{% set ns.m = dict(ns.m, **{area_name(a): ns.lights}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{{ dict(areas=ns.m, states=ns.s, names=ns.n, groups=ns.groups, available=ns.avail) | tojson }}";

    function initialize() {}

    // --- public API ---

    function fetchLightState(callback as Method) as Void {
        var body = { "template" => LIGHT_STATE_TEMPLATE };
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
                _callback.invoke(LightState.fromTemplateData(data), null);
                break;
            case :onService:
                _callback.invoke(true, null);
                break;
        }
    }
}
