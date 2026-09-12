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
        "{% set ns = namespace(areas={}, floors={}) %}" +
        "{% for area in areas() %}" +
        "{% set ns.areas = dict(ns.areas, **{area: dict(name=area_name(area))}) %}" +
        "{% endfor %}" +
        "{% for floor in floors() %}" +
        "{% set ns.floors = dict(ns.floors, **{floor: dict(" +
            "name=floor_name(floor), order=loop.index0, " +
            "areas=floor_areas(floor) | default([]) | list)}) %}" +
        "{% endfor %}" +
        "{{ dict(zone=state_attr('zone.home', 'friendly_name'), " +
            "areas=ns.areas, floors=ns.floors) | tojson }}";

    const VISIBLE_AREA_CLAUSE = "if area not in hidden_areas and (floor_id(area) or '" +
        VisibilityStore.UNFLOORED_FLOOR_ID + "') not in hidden_floors";

    const PRELUDE =
        "{% set groups = integration_entities('group') %}" +
        "{% set ROUNDING = {'temperature': 1} %}" +
        "{% macro physical(ids) %}" +
            "{% set ns = namespace(lights=[]) %}" +
            "{% for entity in ids %}" +
            "{% if entity.startswith('light.') and entity not in groups and states[entity] is not none " +
                "and not is_hidden_entity(entity) %}" +
            "{% set ns.lights = ns.lights + [entity] %}" +
            "{% endif %}" +
            "{% endfor %}" +
            "{{ ns.lights | tojson }}" +
        "{% endmacro %}" +
        "{% macro lightSummary(ids) %}" +
            "{% set ns = namespace(on=0, total=0) %}" +
            "{% for entity in physical(ids) | from_json %}" +
            "{% if not is_state(entity, 'unavailable') %}" +
            "{% set ns.total = ns.total + 1 %}" +
            "{% if is_state(entity, 'on') %}{% set ns.on = ns.on + 1 %}{% endif %}" +
            "{% endif %}" +
            "{% endfor %}" +
            "{% if ns.total > 0 %}" +
            "{{ 'all_on' if ns.on == ns.total else 'all_off' if ns.on == 0 else 'some_on' }}" +
            "{% endif %}" +
        "{% endmacro %}" +
        "{% macro classAverage(ids, deviceClass) %}" +
            "{% set ns = namespace(values=[], unit=none) %}" +
            "{% for entity in ids %}" +
            "{% if entity.startswith('sensor.') and states[entity] is not none and not is_hidden_entity(entity) " +
                "and state_attr(entity, 'device_class') == deviceClass %}" +
            "{% set value = states(entity) | float(none) %}" +
            "{% if value is not none %}" +
            "{% set ns.values = ns.values + [value] %}" +
            "{% set ns.unit = state_attr(entity, 'unit_of_measurement') %}" +
            "{% endif %}" +
            "{% endif %}" +
            "{% endfor %}" +
            "{% if ns.values | count > 0 %}" +
            "{% set precision = ROUNDING.get(deviceClass, 0) %}" +
            "{% set mean = ns.values | average | round(precision) %}" +
            "{% set mean = mean if precision > 0 else mean | int %}" +
            "{{ mean ~ ' ' ~ ns.unit }}" +
            "{% endif %}" +
        "{% endmacro %}" +
        "{% macro averages(ids) %}" +
            "{% set ns = namespace(averages={}) %}" +
            "{% for deviceClass in ['temperature', 'humidity', 'illuminance'] %}" +
            "{% set average = classAverage(ids, deviceClass) | trim %}" +
            "{% if average | length > 0 %}{% set ns.averages = dict(ns.averages, **{deviceClass: average}) %}{% endif %}" +
            "{% endfor %}" +
            "{{ ns.averages | tojson }}" +
        "{% endmacro %}";

    // Group identity comes from the group registry, not `state_attr(e,
    // 'entity_id')`: that attribute vanishes when a group goes unavailable, which
    // would drop a real group to a plain light and lose its place (see #152). An
    // unavailable group is kept (its members are down, not gone); only an
    // available group that expands to nothing — every member hidden — is left out.
    const LIGHTS = PRELUDE +
        "{% set ns = namespace(lights={}, home=[]) %}" +
        "{% for area in areas() " + VISIBLE_AREA_CLAUSE + " %}" +
        "{% set ids = area_entities(area) | list %}" +
        "{% set ns.home = ns.home + ids %}" +
        "{% for entity in ids | reject('is_hidden_entity') | list %}" +
        "{% if entity.startswith('light.') and states[entity] is not none %}" +
        "{% set members = expand(entity) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| map(attribute='entity_id') | list %}" +
        "{% if entity not in groups or members | count > 0 or is_state(entity, 'unavailable') %}" +
        "{% set brightness = state_attr(entity, 'brightness') | default(none) %}" +
        "{% set modes = state_attr(entity, 'supported_color_modes') | default([], true) %}" +
        "{% set light = dict(state=is_state(entity, 'on'), name=states[entity].name, area_id=area, " +
            "available=not is_state(entity, 'unavailable'), " +
            "brightness=(brightness / 255 * 100) | round | int if brightness is not none else none, " +
            "color_temp_kelvin=state_attr(entity, 'color_temp_kelvin') | default(none), " +
            "min_color_temp_kelvin=state_attr(entity, 'min_color_temp_kelvin') | default(none), " +
            "max_color_temp_kelvin=state_attr(entity, 'max_color_temp_kelvin') | default(none), " +
            "supports_color_temp='color_temp' in modes) %}" +
        "{% if entity in groups %}" +
        "{% set light = dict(light, memberIds=members) %}" +
        "{% endif %}" +
        "{% set ns.lights = dict(ns.lights, **{entity: light}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(lights=ns.lights, home=(lightSummary(ns.home) | trim or none)) | tojson }}";

    // The percentage is emitted whatever the state, so an off fan keeps its last
    // speed; the view, not the render, decides what an off fan shows.
    const FANS = PRELUDE +
        "{% set ns = namespace(fans={}) %}" +
        "{% for area in areas() " + VISIBLE_AREA_CLAUSE + " %}" +
        "{% for entity in area_entities(area) | reject('is_hidden_entity') | list %}" +
        "{% if entity.startswith('fan.') and states[entity] is not none %}" +
        "{% set members = expand(entity) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| map(attribute='entity_id') | list %}" +
        "{% if entity not in groups or members | count > 0 or is_state(entity, 'unavailable') %}" +
        "{% set percentage = state_attr(entity, 'percentage') | default(none) %}" +
        "{% set features = state_attr(entity, 'supported_features') | default(0) %}" +
        "{% set fan = dict(state=is_state(entity, 'on'), name=states[entity].name, area_id=area, " +
            "available=not is_state(entity, 'unavailable'), " +
            "speed=percentage | round | int if percentage is not none else none, " +
            "oscillating=state_attr(entity, 'oscillating') | default(none), " +
            "supports_speed=(features | int) % 2 == 1, " +
            "supports_oscillation=(features | int) // 2 % 2 == 1) %}" +
        "{% if entity in groups %}" +
        "{% set fan = dict(fan, memberIds=members) %}" +
        "{% endif %}" +
        "{% set ns.fans = dict(ns.fans, **{entity: fan}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(fans=ns.fans) | tojson }}";

    // `states(e, true, true)` keeps HA's own display precision and unit as a
    // string, so the menu shows exactly what the user's dashboard shows for a
    // single sensor.
    const SENSORS = PRELUDE +
        "{% set ns = namespace(sensors={}, areas={}, floors={}, home=[]) %}" +
        "{% for area in areas() " + VISIBLE_AREA_CLAUSE + " %}" +
        "{% set ids = area_entities(area) | list %}" +
        "{% set ns.home = ns.home + ids %}" +
        "{% set classAverages = averages(ids) | from_json %}" +
        "{% if classAverages | length > 0 %}{% set ns.areas = dict(ns.areas, **{area: classAverages}) %}{% endif %}" +
        "{% for entity in ids | reject('is_hidden_entity') | list %}" +
        "{% if entity.startswith('sensor.') and states[entity] is not none " +
            "and state_attr(entity, 'device_class') in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% set ns.sensors = dict(ns.sensors, **{entity: dict(" +
            "friendly_state=states(entity, true, true), " +
            "device_class=state_attr(entity, 'device_class'), name=entity_name(entity), area_id=area, " +
            "available=not is_state(entity, 'unavailable') and not is_state(entity, 'unknown'))}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{% for floor in floors() %}" +
        "{% set floorEntities = namespace(ids=[]) %}" +
        "{% for area in floor_areas(floor) | default([]) | list if area not in hidden_areas and floor not in hidden_floors %}" +
        "{% set floorEntities.ids = floorEntities.ids + (area_entities(area) | list) %}" +
        "{% endfor %}" +
        "{% set classAverages = averages(floorEntities.ids) | from_json %}" +
        "{% if classAverages | length > 0 %}{% set ns.floors = dict(ns.floors, **{floor: classAverages}) %}{% endif %}" +
        "{% endfor %}" +
        "{{ dict(sensors=ns.sensors, areas=ns.areas, floors=ns.floors, " +
            "home=averages(ns.home) | from_json) | tojson }}";

    // Only the home summaries, so the background process's fetch and parse stay
    // within its small memory pool.
    const GLANCE = PRELUDE +
        "{% set ns = namespace(home=[]) %}" +
        "{% for area in areas() " + VISIBLE_AREA_CLAUSE + " %}" +
        "{% set ns.home = ns.home + (area_entities(area) | list) %}" +
        "{% endfor %}" +
        "{{ dict(lights=(lightSummary(ns.home) | trim or none), " +
            "climate=averages(ns.home) | from_json) | tojson }}";

    // STRUCTURE is never filtered: the settings tree needs every area, hidden or
    // not, to offer un-hiding. The render request has no variables channel, so the
    // hidden sets are inlined as a leading clause of the template itself.
    function resolve(target as Symbol, hiddenFloors as Dictionary<String, Boolean>,
                     hiddenAreas as Dictionary<String, Boolean>) as String {
        if (target == FetchTarget.STRUCTURE) {
            return STRUCTURE;
        }

        var clause = buildHiddenClause(hiddenFloors, hiddenAreas);

        if (target == FetchTarget.LIGHTS) {
            return clause + LIGHTS;
        }
        if (target == FetchTarget.FANS) {
            return clause + FANS;
        }
        if (target == FetchTarget.GLANCE) {
            return clause + GLANCE;
        }
        return clause + SENSORS;
    }

    function buildHiddenClause(hiddenFloors as Dictionary<String, Boolean>,
                               hiddenAreas as Dictionary<String, Boolean>) as String {
        return "{% set hidden_floors = [" + quoteIds(hiddenFloors.keys() as Array<String>) + "] %}" +
            "{% set hidden_areas = [" + quoteIds(hiddenAreas.keys() as Array<String>) + "] %}";
    }

    function quoteIds(ids as Array<String>) as String {
        var quotedIds = "";

        for (var index = 0; index < ids.size(); index++) {
            quotedIds += (index > 0 ? ",'" : "'") + ids[index] + "'";
        }

        return quotedIds;
    }
}
