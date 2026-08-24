import Toybox.Lang;

// The request half of the Home Assistant data contract, whose response half is
// HaPayload: what these templates emit is what HaPayload reads back, so the
// wire key names on both sides live side by side.
//
// Piped through `| tojson`: the render_template webhook returns the rendered
// value as a string, so without it the payload is a Python repr (single quotes,
// True/False, enum units) that no JSON reader accepts. tojson makes it
// well-formed JSON, which JsonParser then decodes on-device.
//
// Deliberately backslash-free: we filter entities with `.startswith(...)`
// instead of a regex like select('match','^light\.'). A backslash in these
// strings would be sent unescaped by the Connect IQ JSON serializer, producing
// an invalid JSON escape and a 400 "Invalid JSON specified" from HA.
//
// Every value reaching a closing `| tojson` is guarded at its own site. An
// Undefined raises TypeError from inside tojson, before any later filter runs,
// so `| tojson | default(...)` cannot catch it — one bad entity would cost the
// whole payload rather than its own row.
module HaTemplate {

    // Every area is emitted, including empty ones: entity targets arrive
    // separately, so an area that looks empty here may be populated later.
    const STRUCTURE =
        "{% set ns = namespace(areasOut={}, floorsOut={}) %}" +
        "{% for a in areas() %}" +
        "{% set ns.areasOut = dict(ns.areasOut, **{a: dict(name=area_name(a))}) %}" +
        "{% endfor %}" +
        "{% for f in floors() %}" +
        "{% set ns.floorsOut = dict(ns.floorsOut, **{f: dict(" +
            "name=floor_name(f), order=loop.index0, " +
            "areas=floor_areas(f) | default([]) | list)}) %}" +
        "{% endfor %}" +
        "{{ dict(zone=state_attr('zone.home', 'friendly_name'), " +
            "areas=ns.areasOut, floors=ns.floorsOut) | tojson }}";

    // Each light carries its own area id and, for a group, its member ids —
    // the area's own light list is gone, so grouping moves to the parser.
    //
    // Group identity comes from the group registry, not `state_attr(e,
    // 'entity_id')`: that attribute vanishes when a group goes unavailable, which
    // would drop a real group to a plain light and lose its place. An unavailable
    // group is kept (its members are down, not gone); only an available group that
    // expands to nothing — every member hidden — is left out.
    const LIGHTS =
        "{% set groups = integration_entities('group') %}" +
        "{% set ns = namespace(out={}) %}" +
        "{% for a in areas() %}" +
        "{% for e in area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('light.') and states[e] is not none %}" +
        "{% set members = expand(e) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| map(attribute='entity_id') | list %}" +
        "{% if e not in groups or members | count > 0 or is_state(e, 'unavailable') %}" +
        "{% set light = dict(state=is_state(e, 'on'), name=states[e].name, area_id=a, " +
            "available=not is_state(e, 'unavailable')) %}" +
        "{% if e in groups %}" +
        "{% set light = dict(light, memberIds=members) %}" +
        "{% endif %}" +
        "{% set ns.out = dict(ns.out, **{e: light}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(lights=ns.out) | tojson }}";

    // `states(e, true, true)` keeps HA's own display precision and unit as a
    // string, so the watch never reparses or rounds and can't disagree with
    // the user's dashboard.
    //
    // `float(none)`, never `float(0)`: a non-numeric state defaulted to 0 is
    // indistinguishable from a sensor genuinely reading zero, so an area mean
    // would silently absorb it — one unavailable sensor plus a real 21.5 °C
    // shows 10.8 °C. null makes the absence visible to the parser instead.
    const SENSORS =
        "{% set ns = namespace(out={}) %}" +
        "{% for a in areas() %}" +
        "{% for e in area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('sensor.') and states[e] is not none " +
            "and state_attr(e, 'device_class') in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% set ns.out = dict(ns.out, **{e: dict(" +
            "state=states(e) | float(none), friendly_state=states(e, true, true), " +
            "display_precision=(states(e, rounded=True) | string).split('.')[1] | default('', true) | length, " +
            "unit=state_attr(e, 'unit_of_measurement'), " +
            "device_class=state_attr(e, 'device_class'), area_id=a, name=entity_name(e), " +
            "available=not is_state(e, 'unavailable') and not is_state(e, 'unknown'))}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(sensors=ns.out) | tojson }}";

    function resolve(target as Symbol) as String {
        if (target == FetchTarget.STRUCTURE) {
            return STRUCTURE;
        }
        if (target == FetchTarget.LIGHTS) {
            return LIGHTS;
        }
        return SENSORS;
    }
}
