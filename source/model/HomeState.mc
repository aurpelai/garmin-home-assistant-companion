import Toybox.Lang;

// Pure data + parsing layer. No networking, no UI — this is the unit-tested core.
//
// The combined HA /api/template call returns a JSON object with the following keys:
//   { "areas":     { areaName: [entityId, ...], ... },
//     "sensors":   { areaName: [entityId, ...], ... },
//     "states":    { entityId: true|false, ... },
//     "names":     { entityId: "Kitchen Island", ... },
//     "groups":    { entityId: memberCount, ... },
//     "readings":  { entityId: "24.6 °C", ... },
//     "available": { entityId: true|false, ... },
//     "floors":    [ { "name": "Upstairs", "areas": ["Kitchen", ...] }, ... ],
//     "kinds":     { entityId: "temperature", ... } }
// HomeState splits that body, joining the areas and sensors sections into one
// area-ordered structure, parsing the states section into an entity_id ->
// Boolean map, parsing the names section into an entity_id -> String map
// (the name Home Assistant itself shows for each entity, used as the row
// label and the light sort key), parsing the groups section into an entity_id ->
// member count map (a light id present in that map is a light group, used
// to order groups ahead of plain lights in the light list; its value is
// how many lights the group controls), parsing the readings section into an
// entity_id -> { value, display, unit } map (the raw number for comparison, HA's
// formatted string for display, and the unit), parsing the available section
// into an entity_id -> Boolean map, parsing the
// floors section into an ordered list of { name, areas } (HA's own floors()
// order, never re-sorted), and parsing the kinds section into an entity_id ->
// device_class String map (temperature/humidity/illuminance).
//
// Each section degrades independently: non-conforming input yields an empty
// result rather than throwing (watch UX: an empty list and all-off defaults, not
// a crash).

class HomeState {
    // Array of { :name => String, :lights => Array<String>, :sensors => Array<String> },
    // sorted by area name.
    public var areas as Array<Dictionary>;
    // entity_id -> Boolean (isOn), the server's on/off truth at load time.
    public var states as Dictionary<String, Boolean>;
    // entity_id -> display name, HA's own name for each entity.
    private var names as Dictionary<String, String>;
    // entity_id -> member count for the light groups. Key presence is the
    // is-a-group signal (backs group-first ordering); the value is how many lights
    // the group controls (backs the "N lights" row sublabel).
    private var groups as Dictionary<String, Number>;
    // Parallel to states, deliberately not folded into it: on/off and
    // availability are independent facts about a light.
    private var available as Dictionary<String, Boolean>;
    // entity_id -> { :value => Float (raw, for comparison), :display => String
    // (HA's formatted string, its own precision + unit), :unit => String }.
    private var readings as Dictionary<String, Dictionary>;
    // Ordered as HA's floors() returns them: Array of
    // { :name => String, :areas => Array<String> } (area names, HA's own order).
    private var floors as Array<Dictionary>;
    // entity_id -> device_class ("temperature"/"humidity"/"illuminance") for
    // sensors; absent for anything the template does not classify.
    private var kinds as Dictionary<String, String>;

    function initialize(areas as Array<Dictionary>, states as Dictionary<String, Boolean>,
                        names as Dictionary<String, String>,
                        groups as Dictionary<String, Number>,
                        available as Dictionary<String, Boolean>,
                        readings as Dictionary<String, Dictionary>,
                        floors as Array<Dictionary>,
                        kinds as Dictionary<String, String>) {
        self.areas = areas;
        self.states = states;
        self.names = names;
        self.groups = groups;
        self.available = available;
        self.readings = readings;
        self.floors = floors;
        self.kinds = kinds;
    }

    // Build from the already-JSON-parsed body of the combined /api/template
    // response. `data` is what Communications hands the callback for a JSON
    // response: the { "areas" => ..., "sensors" => ..., "states" => ...,
    // "names" => ..., "groups" => ..., "readings" => ..., "available" => ...,
    // "floors" => ..., "kinds" => ... } Dictionary. Each section parses
    // defensively; a missing or malformed body yields an empty HomeState.
    static function fromTemplateData(data as Dictionary or String or Null) as HomeState {
        if (!(data instanceof Dictionary)) {
            return new HomeState([] as Array<Dictionary>, {} as Dictionary<String, Boolean>,
                                     {} as Dictionary<String, String>, {} as Dictionary<String, Number>,
                                     {} as Dictionary<String, Boolean>, {} as Dictionary<String, Dictionary>,
                                     [] as Array<Dictionary>, {} as Dictionary<String, String>);
        }
        var body = data as Dictionary;
        return new HomeState(parseAreas(body.get("areas"), body.get("sensors")),
                                 parseBooleanMap(body.get("states")),
                                 parseStringMap(body.get("names")), parseGroups(body.get("groups")),
                                 parseBooleanMap(body.get("available")),
                                 parseReadings(body.get("readings")),
                                 parseFloors(body.get("floors")),
                                 parseStringMap(body.get("kinds")));
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    function isOn(entityId as String) as Boolean {
        var state = states.get(entityId);
        return (state == null) ? false : (state as Boolean);
    }

    // The template emits an availability entry for every entity, so a null here
    // means a server-contract violation (as with isOn). It defaults to available
    // rather than off: a contract breach must not mark a working light down.
    function isAvailable(entityId as String) as Boolean {
        var value = available.get(entityId);
        return (value == null) ? true : (value as Boolean);
    }

    // A sensor's value as HA formatted it (its own precision and unit), or null
    // when the payload carries no reading for the id — which the row renders as
    // unavailable.
    function getReading(entityId as String) as String or Null {
        var reading = readings.get(entityId);
        return (reading == null) ? null : (reading as Dictionary).get(:display) as String or Null;
    }

    // A sensor's raw numeric value, for comparison (ranges). Null when the
    // payload carries no reading for the id.
    function getReadingValue(entityId as String) as Float or Null {
        var reading = readings.get(entityId);
        return (reading == null) ? null : (reading as Dictionary).get(:value) as Float or Null;
    }

    // A sensor's unit, for composing a range that shows the unit once. Null when
    // the payload carries no reading for the id.
    function getReadingUnit(entityId as String) as String or Null {
        var reading = readings.get(entityId);
        return (reading == null) ? null : (reading as Dictionary).get(:unit) as String or Null;
    }

    // A sensor's device_class ("temperature"/"humidity"/"illuminance"), or null
    // when the payload carries no kind for the id.
    function getKind(entityId as String) as String or Null {
        return kinds.get(entityId);
    }

    // HA's display name for an entity. Falls back to the bare entity id when the
    // server sent no usable name — an empty name counts as none. This fallback
    // only fires on a server-contract violation (the template sends a name for
    // every entity); it needs to be non-blank, not pretty.
    function getName(entityId as String) as String {
        var name = names.get(entityId);
        if (name == null || (name as String).equals("")) {
            return entityId;
        }
        return name as String;
    }

    function isGroup(entityId as String) as Boolean {
        return groups.hasKey(entityId);
    }

    // How many lights the group controls. Only meaningful for a group (isGroup
    // true); parseGroups guarantees every present key maps to a non-negative
    // integer, so this never returns null for a group.
    function getMemberCount(entityId as String) as Number {
        return groups.get(entityId) as Number;
    }

    function listLightsInArea(name as String) as Array<String> {
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            if ((areas[areaIndex].get(:name) as String).equals(name)) {
                return orderAvailableFirst(areas[areaIndex].get(:lights) as Array<String>);
            }
        }
        return [] as Array<String>;
    }

    // Payload order is display order: the template already groups an area's
    // sensors by kind, so nothing is sorted here.
    function listSensorsInArea(name as String) as Array<String> {
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            if ((areas[areaIndex].get(:name) as String).equals(name)) {
                return areas[areaIndex].get(:sensors) as Array<String>;
            }
        }
        return [] as Array<String>;
    }

    // The ordered, grouped floor structure the card loop walks: one entry per
    // floor in floors()-order, each carrying its areas sorted alphabetically
    // (input order is not trusted for areas), followed by a trailing entry
    // (:name => null) for any area belonging to no floor, also alphabetical.
    // Zero floors (or an unfloored-only home) yields just that trailing entry;
    // a home with no areas at all yields an empty array.
    //
    // Each entry is { :name => String or Null, :areas => Array<String> }.
    function buildFloorGroups() as Array<Dictionary> {
        var floored = {} as Dictionary<String, Boolean>;
        var out = [] as Array<Dictionary>;

        for (var floorIndex = 0; floorIndex < floors.size(); floorIndex++) {
            var floor = floors[floorIndex];
            var floorAreas = sortAreaNames(floor.get(:areas) as Array<String>);
            if (floorAreas.size() == 0) {
                continue;
            }
            for (var areaIndex = 0; areaIndex < floorAreas.size(); areaIndex++) {
                floored.put(floorAreas[areaIndex], true);
            }
            out.add({ :name => floor.get(:name) as String, :areas => floorAreas });
        }

        var unfloored = [] as Array<String>;
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            var name = areas[areaIndex].get(:name) as String;
            if (!floored.hasKey(name)) {
                unfloored.add(name);
            }
        }
        if (unfloored.size() > 0) {
            out.add({ :name => null, :areas => sortAreaNames(unfloored) });
        }

        return out;
    }

    // Order area names alphabetically, case-insensitively. Only areas that
    // actually hold entities (present in `areas`) are kept — a floor's areas
    // list may name an area the areas/sensors sections dropped for holding
    // neither.
    private function sortAreaNames(names as Array<String>) as Array<String> {
        var kept = [] as Array<String>;
        for (var index = 0; index < names.size(); index++) {
            if (hasArea(names[index])) {
                kept.add(names[index]);
            }
        }

        var keyed = {} as Dictionary<String, String>;
        var keys = [] as Array<String>;
        for (var index = 0; index < kept.size(); index++) {
            var name = kept[index];
            var key = name.toLower() + "\n" + name;
            keyed.put(key, name);
            keys.add(key);
        }
        keys.sort(null);

        var ordered = [] as Array<String>;
        for (var index = 0; index < keys.size(); index++) {
            ordered.add(keyed.get(keys[index]) as String);
        }
        return ordered;
    }

    private function hasArea(name as String) as Boolean {
        for (var index = 0; index < areas.size(); index++) {
            if ((areas[index].get(:name) as String).equals(name)) {
                return true;
            }
        }
        return false;
    }

    // Availability is the primary partition: every available light precedes every
    // unavailable one, with the group-first ordering re-run within each partition.
    private function orderAvailableFirst(ids as Array<String>) as Array<String> {
        var availableIds = [] as Array<String>;
        var unavailableIds = [] as Array<String>;
        for (var index = 0; index < ids.size(); index++) {
            var entityId = ids[index];
            if (isAvailable(entityId)) {
                availableIds.add(entityId);
            } else {
                unavailableIds.add(entityId);
            }
        }

        var ordered = orderGroupsFirst(availableIds);
        ordered.addAll(orderGroupsFirst(unavailableIds));
        return ordered;
    }

    // Light groups first (by name among themselves), then plain lights (by name
    // among themselves). Groups aggregate several lights, so they read as the
    // primary controls and belong at the top of every list. Ordering is by the
    // name the user sees, case-insensitively, so the list scans alphabetically
    // on the visible label rather than the hidden entity id.
    private function orderGroupsFirst(ids as Array<String>) as Array<String> {
        var grouped = [] as Array<String>;
        var plain = [] as Array<String>;
        for (var index = 0; index < ids.size(); index++) {
            var entityId = ids[index];
            if (isGroup(entityId)) {
                grouped.add(entityId);
            } else {
                plain.add(entityId);
            }
        }

        var ordered = sortByName(grouped);
        ordered.addAll(sortByName(plain));
        return ordered;
    }

    // Order entity ids by their display name, case-insensitively, with the id as
    // a tiebreaker for equal names (deterministic order for same-named lights).
    //
    // Decorate-sort-undecorate: build one sort key per id — lower-cased name,
    // then a newline, then the id — sort those keys with the platform's native
    // string sort, then map each sorted key back to its id. The newline
    // separator sorts below every printable character, so the key orders by name
    // first and by id only within an equal name; ending the key with the unique
    // id also makes every key unique. The name is lower-cased once here, not on
    // every comparison. Mapping back through a key->id lookup (rather than
    // slicing the id out of the key) keeps this correct even if a name were to
    // contain the separator. ASCII-scoped: the platform's toLower has no defined
    // behavior for non-ASCII, so accented/non-Latin names order by code point,
    // not locale collation.
    private function sortByName(ids as Array<String>) as Array<String> {
        var idForKey = {} as Dictionary<String, String>;
        var keys = [] as Array<String>;
        for (var index = 0; index < ids.size(); index++) {
            var entityId = ids[index];
            var key = getName(entityId).toLower() + "\n" + entityId;
            idForKey.put(key, entityId);
            keys.add(key);
        }

        keys.sort(null);

        var ordered = [] as Array<String>;
        for (var index = 0; index < keys.size(); index++) {
            ordered.add(idForKey.get(keys[index]) as String);
        }
        return ordered;
    }

    // --- section parsers ---

    // The "areas" and "sensors" sections, both { areaName: [entityId, ...] } ->
    // one area-ordered array sorted by name. Area names come from the "areas"
    // section, which the template emits for every area it emits sensors for, an
    // empty list included. An area is kept when it holds at least one entity of
    // either kind after filtering.
    private static function parseAreas(rawLights as Object or Null,
                                       rawSensors as Object or Null) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        if (!(rawLights instanceof Dictionary)) {
            return out;
        }

        var sensorSection = {} as Dictionary;
        if (rawSensors instanceof Dictionary) {
            sensorSection = rawSensors as Dictionary;
        }

        var names = (rawLights as Dictionary).keys() as Array<String>;
        names.sort(null);

        for (var index = 0; index < names.size(); index++) {
            var name = names[index] as String;
            var lights = onlyStrings((rawLights as Dictionary).get(name));
            var sensors = onlyStrings(sensorSection.get(name));
            if (lights.size() + sensors.size() > 0) {
                out.add({ :name => name, :lights => lights, :sensors => sensors });
            }
        }
        return out;
    }

    // The "states" and "available" sections, both { entityId: bool } -> an
    // entity_id -> Boolean map, dropping non-String keys and non-Boolean values.
    private static function parseBooleanMap(raw as Object or Null) as Dictionary<String, Boolean> {
        var out = {} as Dictionary<String, Boolean>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }
        var section = raw as Dictionary;
        var entityIds = section.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var value = section.get(entityId);
            if (entityId instanceof String && value instanceof Boolean) {
                out.put(entityId as String, value as Boolean);
            }
        }
        return out;
    }

    // The "names" and "kinds" sections, both { entityId: text } -> an
    // entity_id -> String map, dropping non-String keys and non-String values.
    private static function parseStringMap(raw as Object or Null) as Dictionary<String, String> {
        var out = {} as Dictionary<String, String>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }
        var section = raw as Dictionary;
        var entityIds = section.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var value = section.get(entityId);
            if (entityId instanceof String && value instanceof String) {
                out.put(entityId as String, value as String);
            }
        }
        return out;
    }

    // The "readings" section: { entityId: { value, display, unit } } -> an
    // entity_id -> { :value => Float, :display => String, :unit => String } map.
    // An entry is kept only when it carries a String display (the row's text);
    // value defaults to 0.0 and unit to "" when absent or the wrong type.
    private static function parseReadings(raw as Object or Null) as Dictionary<String, Dictionary> {
        var out = {} as Dictionary<String, Dictionary>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }
        var section = raw as Dictionary;
        var entityIds = section.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var entry = section.get(entityId);
            if (!(entityId instanceof String) || !(entry instanceof Dictionary)) {
                continue;
            }
            var display = (entry as Dictionary).get("display");
            if (!(display instanceof String)) {
                continue;
            }
            var value = (entry as Dictionary).get("value");
            var unit = (entry as Dictionary).get("unit");
            out.put(entityId as String, {
                :value => (value instanceof Float || value instanceof Number) ? (value as Number).toFloat() : 0.0,
                :display => display as String,
                :unit => (unit instanceof String) ? unit as String : ""
            });
        }
        return out;
    }

    // The "groups" section: { entityId: memberCount } -> entity_id -> Number.
    // Keeps only entries with a String key and a non-negative-integer value; a
    // non-Dictionary or missing value yields an empty map. Dropping any entry
    // whose value is not a valid count (null, string, array, negative) is a
    // crash guard, not polish: a present key must always carry a usable count, or
    // the null would flow to the row sublabel's string concatenation and throw at
    // row-build time. In normal operation the server-side count filter can only
    // emit a valid integer; the invalid case is reachable only via a
    // server-contract violation, and dropping the entry degrades it to a plain
    // (non-group) row.
    private static function parseGroups(raw as Object or Null) as Dictionary<String, Number> {
        var out = {} as Dictionary<String, Number>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }
        var section = raw as Dictionary;
        var entityIds = section.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var count = section.get(entityId);
            if (entityId instanceof String && count instanceof Number && (count as Number) >= 0) {
                out.put(entityId as String, count as Number);
            }
        }
        return out;
    }

    // The "floors" section: [ { "name": String, "areas": [String, ...] }, ... ]
    // -> an Array of { :name => String, :areas => Array<String> }, in input
    // order (HA's floors() order — never re-sorted here). A malformed entry
    // (non-Dictionary, non-String name, or non-Array areas) is dropped; a
    // malformed areas list keeps only its String elements.
    private static function parseFloors(raw as Object or Null) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        if (!(raw instanceof Array)) {
            return out;
        }
        var entries = raw as Array;
        for (var index = 0; index < entries.size(); index++) {
            var entry = entries[index];
            if (!(entry instanceof Dictionary)) {
                continue;
            }
            var name = (entry as Dictionary).get("name");
            if (!(name instanceof String)) {
                continue;
            }
            out.add({ :name => name as String, :areas => onlyStrings((entry as Dictionary).get("areas")) });
        }
        return out;
    }

    // --- helpers ---

    // Keep only String elements of a value that should be an Array<String>.
    private static function onlyStrings(raw as Object or Null) as Array<String> {
        var out = [] as Array<String>;
        if (!(raw instanceof Array)) {
            return out;
        }
        var items = raw as Array;
        for (var index = 0; index < items.size(); index++) {
            if (items[index] instanceof String) {
                out.add(items[index] as String);
            }
        }
        return out;
    }
}
