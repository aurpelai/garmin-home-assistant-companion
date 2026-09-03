import Toybox.Lang;

// Piped through `| tojson` because the render_template webhook returns the
// rendered value as a string; without it the payload is a Python repr no JSON
// reader accepts (see #73).
//
// UNVERIFIED: kept backslash-free (`.startswith(...)`, never a `match` regex)
// because a backslash is sent unescaped by the Connect IQ JSON serializer,
// producing a 400 "Invalid JSON specified" from HA.
//
// UNVERIFIED: an Undefined raises TypeError inside tojson before any later
// filter runs, so `| tojson | default(...)` cannot catch it — hence each value
// is guarded at its own site (see #109).
//
// Home-wide aggregates reduce the union of every area's `area_entities`, never
// `states.*` globally: a global sweep drags in area-less strays like weather
// forecasts that skew the mean.
(:background)
module HaTemplate {

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

    const PRELUDE =
        "{% set groups = integration_entities('group') %}" +
        "{% set ROUNDING = {'temperature': 1} %}" +
        "{% macro physical(ids) %}" +
            "{% set ns = namespace(out=[]) %}" +
            "{% for e in ids %}" +
            "{% if e.startswith('light.') and e not in groups and states[e] is not none " +
                "and not is_hidden_entity(e) %}" +
            "{% set ns.out = ns.out + [e] %}" +
            "{% endif %}" +
            "{% endfor %}" +
            "{{ ns.out | tojson }}" +
        "{% endmacro %}" +
        "{% macro lightSummary(ids) %}" +
            "{% set lit = namespace(on=0, total=0) %}" +
            "{% for e in physical(ids) | from_json %}" +
            "{% if not is_state(e, 'unavailable') %}" +
            "{% set lit.total = lit.total + 1 %}" +
            "{% if is_state(e, 'on') %}{% set lit.on = lit.on + 1 %}{% endif %}" +
            "{% endif %}" +
            "{% endfor %}" +
            "{% if lit.total > 0 %}" +
            "{{ 'all_on' if lit.on == lit.total else 'all_off' if lit.on == 0 else 'some_on' }}" +
            "{% endif %}" +
        "{% endmacro %}" +
        "{% macro classAverage(ids, cls) %}" +
            "{% set v = namespace(nums=[], unit=none) %}" +
            "{% for e in ids %}" +
            "{% if e.startswith('sensor.') and states[e] is not none and not is_hidden_entity(e) " +
                "and state_attr(e, 'device_class') == cls %}" +
            "{% set n = states(e) | float(none) %}" +
            "{% if n is not none %}" +
            "{% set v.nums = v.nums + [n] %}" +
            "{% set v.unit = state_attr(e, 'unit_of_measurement') %}" +
            "{% endif %}" +
            "{% endif %}" +
            "{% endfor %}" +
            "{% if v.nums | count > 0 %}" +
            "{% set p = ROUNDING.get(cls, 0) %}" +
            "{% set m = v.nums | average | round(p) %}" +
            "{% set m = m if p > 0 else m | int %}" +
            "{{ m ~ ' ' ~ v.unit }}" +
            "{% endif %}" +
        "{% endmacro %}" +
        "{% macro averages(ids) %}" +
            "{% set out = namespace(d={}) %}" +
            "{% for cls in ['temperature', 'humidity', 'illuminance'] %}" +
            "{% set r = classAverage(ids, cls) | trim %}" +
            "{% if r | length > 0 %}{% set out.d = dict(out.d, **{cls: r}) %}{% endif %}" +
            "{% endfor %}" +
            "{{ out.d | tojson }}" +
        "{% endmacro %}";

    // Group identity comes from the group registry, not `state_attr(e,
    // 'entity_id')`: that attribute vanishes when a group goes unavailable, which
    // would drop a real group to a plain light and lose its place (see #152). An
    // unavailable group is kept (its members are down, not gone); only an
    // available group that expands to nothing — every member hidden — is left out.
    const LIGHTS = PRELUDE +
        "{% set ns = namespace(out={}, home=[]) %}" +
        "{% for a in areas() %}" +
        "{% set ids = area_entities(a) | list %}" +
        "{% set ns.home = ns.home + ids %}" +
        "{% for e in ids | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('light.') and states[e] is not none %}" +
        "{% set members = expand(e) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| map(attribute='entity_id') | list %}" +
        "{% if e not in groups or members | count > 0 or is_state(e, 'unavailable') %}" +
        "{% set b = state_attr(e, 'brightness') | default(none) %}" +
        "{% set modes = state_attr(e, 'supported_color_modes') | default([], true) %}" +
        "{% set light = dict(state=is_state(e, 'on'), name=states[e].name, area_id=a, " +
            "available=not is_state(e, 'unavailable'), " +
            "brightness=(b / 255 * 100) | round | int if b is not none else none, " +
            "color_temp_kelvin=state_attr(e, 'color_temp_kelvin') | default(none), " +
            "min_color_temp_kelvin=state_attr(e, 'min_color_temp_kelvin') | default(none), " +
            "max_color_temp_kelvin=state_attr(e, 'max_color_temp_kelvin') | default(none), " +
            "supports_color_temp='color_temp' in modes) %}" +
        "{% if e in groups %}" +
        "{% set light = dict(light, memberIds=members) %}" +
        "{% endif %}" +
        "{% set ns.out = dict(ns.out, **{e: light}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(lights=ns.out, home=(lightSummary(ns.home) | trim or none)) | tojson }}";

    // The percentage is emitted whatever the state, so an off fan keeps its last
    // speed; the view, not the render, decides what an off fan shows.
    const FANS = PRELUDE +
        "{% set ns = namespace(out={}) %}" +
        "{% for a in areas() %}" +
        "{% for e in area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('fan.') and states[e] is not none %}" +
        "{% set members = expand(e) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| map(attribute='entity_id') | list %}" +
        "{% if e not in groups or members | count > 0 or is_state(e, 'unavailable') %}" +
        "{% set p = state_attr(e, 'percentage') | default(none) %}" +
        "{% set feat = state_attr(e, 'supported_features') | default(0) %}" +
        "{% set fan = dict(state=is_state(e, 'on'), name=states[e].name, area_id=a, " +
            "available=not is_state(e, 'unavailable'), " +
            "speed=p | round | int if p is not none else none, " +
            "oscillating=state_attr(e, 'oscillating') | default(none), " +
            "supports_speed=(feat | int) % 2 == 1, " +
            "supports_oscillation=(feat | int) // 2 % 2 == 1) %}" +
        "{% if e in groups %}" +
        "{% set fan = dict(fan, memberIds=members) %}" +
        "{% endif %}" +
        "{% set ns.out = dict(ns.out, **{e: fan}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(fans=ns.out) | tojson }}";

    // `states(e, true, true)` keeps HA's own display precision and unit as a
    // string, so the menu shows exactly what the user's dashboard shows for a
    // single sensor.
    const SENSORS = PRELUDE +
        "{% set ns = namespace(out={}, areas={}, floors={}, home=[]) %}" +
        "{% for a in areas() %}" +
        "{% set ids = area_entities(a) | list %}" +
        "{% set ns.home = ns.home + ids %}" +
        "{% set m = averages(ids) | from_json %}" +
        "{% if m | length > 0 %}{% set ns.areas = dict(ns.areas, **{a: m}) %}{% endif %}" +
        "{% for e in ids | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('sensor.') and states[e] is not none " +
            "and state_attr(e, 'device_class') in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% set ns.out = dict(ns.out, **{e: dict(" +
            "friendly_state=states(e, true, true), " +
            "device_class=state_attr(e, 'device_class'), name=entity_name(e), area_id=a, " +
            "available=not is_state(e, 'unavailable') and not is_state(e, 'unknown'))}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{% for f in floors() %}" +
        "{% set fids = namespace(l=[]) %}" +
        "{% for a in floor_areas(f) | default([]) | list %}" +
        "{% set fids.l = fids.l + (area_entities(a) | list) %}" +
        "{% endfor %}" +
        "{% set m = averages(fids.l) | from_json %}" +
        "{% if m | length > 0 %}{% set ns.floors = dict(ns.floors, **{f: m}) %}{% endif %}" +
        "{% endfor %}" +
        "{{ dict(sensors=ns.out, areas=ns.areas, floors=ns.floors, " +
            "home=averages(ns.home) | from_json) | tojson }}";

    // Only the home summaries, so the background process's fetch and parse stay
    // within its small memory pool.
    const GLANCE = PRELUDE +
        "{% set ns = namespace(home=[]) %}" +
        "{% for a in areas() %}" +
        "{% set ns.home = ns.home + (area_entities(a) | list) %}" +
        "{% endfor %}" +
        "{{ dict(lights=(lightSummary(ns.home) | trim or none), " +
            "climate=averages(ns.home) | from_json) | tojson }}";

    function resolve(target as Symbol) as String {
        if (target == FetchTarget.STRUCTURE) {
            return STRUCTURE;
        }
        if (target == FetchTarget.LIGHTS) {
            return LIGHTS;
        }
        if (target == FetchTarget.FANS) {
            return FANS;
        }
        if (target == FetchTarget.GLANCE) {
            return GLANCE;
        }
        return SENSORS;
    }
}
