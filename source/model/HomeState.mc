import Toybox.Lang;

// Pure data + parsing layer. No networking, no UI — this is the unit-tested core.
//
// The combined HA /api/template call returns a JSON object with seven keys:
//   { "areas":     { areaName: [entityId, ...], ... },
//     "sensors":   { areaName: [entityId, ...], ... },
//     "states":    { entityId: true|false, ... },
//     "names":     { entityId: "Kitchen Island", ... },
//     "groups":    { entityId: memberCount, ... },
//     "readings":  { entityId: "24.6 °C", ... },
//     "available": { entityId: true|false, ... } }
// HomeState splits that body, joining the areas and sensors sections into one
// area-ordered structure, parsing the states section into an entity_id ->
// Boolean map, parsing the names section into an entity_id -> String map
// (the name Home Assistant itself shows for each entity, used as the row
// label and the light sort key), parsing the groups section into an entity_id ->
// member count map (a light id present in that map is a light group, used
// to order groups ahead of plain lights in the light list; its value is
// how many lights the group controls), parsing the readings section into an
// entity_id -> String map (each sensor's value as Home Assistant formatted it),
// and parsing the available section into an entity_id -> Boolean map.
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
    // entity_id -> the sensor's value as HA formatted it, unit included.
    private var readings as Dictionary<String, String>;

    function initialize(areas as Array<Dictionary>, states as Dictionary<String, Boolean>,
                        names as Dictionary<String, String>,
                        groups as Dictionary<String, Number>,
                        available as Dictionary<String, Boolean>,
                        readings as Dictionary<String, String>) {
        self.areas = areas;
        self.states = states;
        self.names = names;
        self.groups = groups;
        self.available = available;
        self.readings = readings;
    }

    // Build from the already-JSON-parsed body of the combined /api/template
    // response. `data` is what Communications hands the callback for a JSON
    // response: the seven-key { "areas" => ..., "sensors" => ..., "states" => ...,
    // "names" => ..., "groups" => ..., "readings" => ..., "available" => ... }
    // Dictionary. Each section parses defensively; a missing or malformed body
    // yields an empty HomeState.
    static function fromTemplateData(data as Dictionary or String or Null) as HomeState {
        if (!(data instanceof Dictionary)) {
            return new HomeState([] as Array<Dictionary>, {} as Dictionary<String, Boolean>,
                                     {} as Dictionary<String, String>, {} as Dictionary<String, Number>,
                                     {} as Dictionary<String, Boolean>, {} as Dictionary<String, String>);
        }
        var body = data as Dictionary;
        return new HomeState(parseAreas(body.get("areas"), body.get("sensors")),
                                 parseBooleanMap(body.get("states")),
                                 parseStringMap(body.get("names")), parseGroups(body.get("groups")),
                                 parseBooleanMap(body.get("available")),
                                 parseStringMap(body.get("readings")));
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

    // A sensor's value as HA formatted it, or null when the payload carries no
    // reading for the id — which the row renders as unavailable.
    function getReading(entityId as String) as String or Null {
        return readings.get(entityId);
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

    // The "names" and "readings" sections, both { entityId: text } -> an
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
