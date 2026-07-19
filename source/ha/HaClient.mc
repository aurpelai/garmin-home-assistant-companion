import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Networking core. Wraps Communications.makeWebRequest with Bearer auth and
// JSON, and exposes the three operations the UI needs:
//   - fetchAreaLightMap: one POST /api/template call, server-side areas→lights join
//   - fetchStates:       GET /api/states for current on/off per entity
//   - callLightService:  POST /api/services/light/{turn_on|turn_off|toggle}
//
// Connect IQ is single-threaded and callback-based: every method takes a
// Lang.Method callback invoked with the parsed result. Callers sequence
// dependent requests by chaining in their callbacks.
class HaClient {

    // Jinja rendered by HA. Must end in `| tojson` — /api/template returns plain
    // text, so without it the body would be a Python-repr dict, not valid JSON.
    //
    // Deliberately backslash-free: we filter light entities with
    // `.startswith('light.')` instead of a regex like select('match','^light\.').
    // A backslash in this string would be sent unescaped by the Connect IQ JSON
    // serializer, producing an invalid JSON escape and a 400 "Invalid JSON
    // specified" from HA.
    private const AREA_LIGHTS_TEMPLATE =
        "{% set ns = namespace(m={}) %}" +
        "{% for a in areas() %}" +
        "{% set ns.lights = [] %}" +
        "{% for e in area_entities(a) %}" +
        "{% if e.startswith('light.') %}" +
        "{% set ns.lights = ns.lights + [e] %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% if ns.lights | count > 0 %}" +
        "{% set ns.m = dict(ns.m, **{area_name(a): ns.lights}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{{ ns.m | tojson }}";

    function initialize() {}

    // --- public API ---

    // callback: method(result as AreaLightMap, err as Number or Null)
    function fetchAreaLightMap(callback as Method) as Void {
        var body = { "template" => AREA_LIGHTS_TEMPLATE };
        post("/api/template", body, new Responder(callback, :onTemplate));
    }

    // callback: method(states as Dictionary<String, Boolean>, err as Number or Null)
    // Maps entity_id -> isOn for every light entity in /api/states.
    function fetchStates(callback as Method) as Void {
        get("/api/states", new Responder(callback, :onStates));
    }

    // Toggle/turn a single light. callback: method(ok as Boolean, err as Number or Null)
    function callLightService(service as Number, entityId as String, callback as Method) as Void {
        post(ServiceCall.servicePath(service), ServiceCall.entityBody(entityId),
             new Responder(callback, :onService));
    }

    // Toggle/turn a whole area by sending its entity list as an array. HA accepts
    // an array for entity_id — this avoids relying on area_id at the REST layer.
    function callAreaService(service as Number, entityIds as Array<String>, callback as Method) as Void {
        post(ServiceCall.servicePath(service), { "entity_id" => entityIds },
             new Responder(callback, :onService));
    }

    // --- transport ---

    private function get(path as String, responder as Responder) as Void {
        Communications.makeWebRequest(
            Settings.getBaseUrl() + path, null, options(Communications.HTTP_REQUEST_METHOD_GET),
            responder.method(:onResponse));
    }

    private function post(path as String, body as Dictionary, responder as Responder) as Void {
        Communications.makeWebRequest(
            Settings.getBaseUrl() + path, body as Dictionary<Object, Object>,
            options(Communications.HTTP_REQUEST_METHOD_POST),
            responder.method(:onResponse));
    }

    // Typed to the shape makeWebRequest expects for its options argument, so it
    // matches under strict type checking (-l 3).
    private function options(httpMethod as Communications.HttpRequestMethod) as {
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
class Responder {
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
                // the empty-menu case is diagnosable.
                if (data instanceof Lang.String) {
                    System.println("Template returned unparsed String: " + data);
                }
                _callback.invoke(AreaLightMap.fromTemplateData(data), null);
                break;
            case :onStates:
                _callback.invoke(parseStates(data), null);
                break;
            case :onService:
                _callback.invoke(true, null);
                break;
        }
    }

    // /api/states → Array of { "entity_id" => ..., "state" => "on"|"off", ... }.
    // Reduce to entity_id -> isOn for light.* entities only.
    private function parseStates(data as Object or Null) as Dictionary<String, Boolean> {
        var out = {} as Dictionary<String, Boolean>;
        if (!(data instanceof Array)) {
            return out;
        }
        var arr = data as Array;
        for (var i = 0; i < arr.size(); i++) {
            var e = arr[i];
            if (e instanceof Dictionary) {
                var id = e.get("entity_id");
                var state = e.get("state");
                if (id instanceof String && (id as String).find("light.") == 0 && state instanceof String) {
                    out.put(id as String, (state as String).equals("on"));
                }
            }
        }
        return out;
    }
}
