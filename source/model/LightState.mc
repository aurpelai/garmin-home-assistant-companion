import Toybox.Lang;

// Pure data + parsing layer. No networking, no UI — this is the unit-tested core.
//
// The combined HA /api/template call returns a JSON object with five keys:
//   { "areas":     { areaName: [entityId, ...], ... },
//     "states":    { entityId: true|false, ... },
//     "names":     { entityId: "Kitchen Island", ... },
//     "groups":    { entityId: memberCount, ... },
//     "available": { entityId: true|false, ... } }
// LightState splits that body, wrapping the areas section into an
// area-ordered structure (from which the flat "all lights" list derives),
// parsing the states section into an entity_id -> Boolean map, parsing the
// names section into an entity_id -> String map (the name Home Assistant
// itself shows for each light, used as the row label and the sort key),
// parsing the groups section into an entity_id -> member count map (a light id
// present in that map is a light group, used to order groups ahead of plain
// lights in every list view; its value is how many lights the group controls),
// and parsing the available section into an entity_id -> Boolean map.
//
// Each section degrades independently: non-conforming input yields an empty
// result rather than throwing (watch UX: show "no lights" / all-off, not a
// crash).

class LightState {
    // Array of { :name => String, :lights => Array<String> }, sorted by area name.
    public var areas as Array<Dictionary>;
    // entity_id -> Boolean (isOn), the server's on/off truth at load time.
    public var states as Dictionary<String, Boolean>;
    // entity_id -> display name, HA's own name for each light.
    private var names as Dictionary<String, String>;
    // entity_id -> member count for the light groups. Key presence is the
    // is-a-group signal (backs group-first ordering); the value is how many lights
    // the group controls (backs the "N lights" row sublabel).
    private var groups as Dictionary<String, Number>;
    // Parallel to states, deliberately not folded into it: on/off and
    // availability are independent facts about a light.
    private var available as Dictionary<String, Boolean>;

    function initialize(areas as Array<Dictionary>, states as Dictionary<String, Boolean>,
                        names as Dictionary<String, String>,
                        groups as Dictionary<String, Number>,
                        available as Dictionary<String, Boolean>) {
        self.areas = areas;
        self.states = states;
        self.names = names;
        self.groups = groups;
        self.available = available;
    }

    // Build from the already-JSON-parsed body of the combined /api/template
    // response. `data` is what Communications hands the callback for a JSON
    // response: the five-key { "areas" => ..., "states" => ..., "names" => ...,
    // "groups" => ..., "available" => ... } Dictionary. Each section parses
    // defensively; a missing or malformed body yields an empty LightState.
    static function fromTemplateData(data as Dictionary or String or Null) as LightState {
        if (!(data instanceof Dictionary)) {
            return new LightState([] as Array<Dictionary>, {} as Dictionary<String, Boolean>,
                                     {} as Dictionary<String, String>, {} as Dictionary<String, Number>,
                                     {} as Dictionary<String, Boolean>);
        }
        var body = data as Dictionary;
        return new LightState(parseAreas(body.get("areas")), parseStates(body.get("states")),
                                 parseNames(body.get("names")), parseGroups(body.get("groups")),
                                 parseAvailable(body.get("available")));
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    function isOn(entityId as String) as Boolean {
        var state = states.get(entityId);
        return (state == null) ? false : (state as Boolean);
    }

    // Absent entities default to available (contrast isOn, which defaults them
    // off) — missing availability info must never mark a light unavailable.
    function isAvailable(entityId as String) as Boolean {
        var value = available.get(entityId);
        return (value == null) ? true : (value as Boolean);
    }

    // HA's display name for a light. Falls back to the bare entity id when the
    // server sent no usable name — an empty name counts as none. This fallback
    // only fires on a server-contract violation (the template sends a name for
    // every light); it needs to be non-blank, not pretty.
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

    // Deduplicated, group-first-then-alphabetical union of every area's lights —
    // backs the "All lights" view.
    function listAllLights() as Array<String> {
        var seen = {} as Dictionary<String, Boolean>;
        var flat = [] as Array<String>;
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            var lights = areas[areaIndex].get(:lights) as Array<String>;
            for (var lightIndex = 0; lightIndex < lights.size(); lightIndex++) {
                var entityId = lights[lightIndex];
                if (!seen.hasKey(entityId)) {
                    seen.put(entityId, true);
                    flat.add(entityId);
                }
            }
        }
        return orderAvailableFirst(flat);
    }

    function listLightsInArea(name as String) as Array<String> {
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            if ((areas[areaIndex].get(:name) as String).equals(name)) {
                return orderAvailableFirst(areas[areaIndex].get(:lights) as Array<String>);
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

    // The "areas" section: { areaName: [entityId, ...] } -> area-ordered array
    // sorted by name, skipping areas whose light list is empty after filtering.
    private static function parseAreas(raw as Object or Null) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var names = (raw as Dictionary).keys() as Array<String>;
        names.sort(null);

        for (var index = 0; index < names.size(); index++) {
            var name = names[index] as String;
            var lights = onlyStrings((raw as Dictionary).get(name));
            if (lights.size() > 0) {
                out.add({ :name => name, :lights => lights });
            }
        }
        return out;
    }

    // The "states" section: { entityId: bool } -> entity_id -> Boolean, dropping
    // non-String keys and non-Boolean values.
    private static function parseStates(raw as Object or Null) as Dictionary<String, Boolean> {
        var out = {} as Dictionary<String, Boolean>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }
        var section = raw as Dictionary;
        var entityIds = section.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var state = section.get(entityId);
            if (entityId instanceof String && state instanceof Boolean) {
                out.put(entityId as String, state as Boolean);
            }
        }
        return out;
    }

    // The "available" section: { entityId: bool } -> entity_id -> Boolean, dropping
    // non-String keys and non-Boolean values.
    private static function parseAvailable(raw as Object or Null) as Dictionary<String, Boolean> {
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

    // The "names" section: { entityId: name } -> entity_id -> String, dropping
    // non-String keys and non-String values.
    private static function parseNames(raw as Object or Null) as Dictionary<String, String> {
        var out = {} as Dictionary<String, String>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }
        var section = raw as Dictionary;
        var entityIds = section.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var name = section.get(entityId);
            if (entityId instanceof String && name instanceof String) {
                out.put(entityId as String, name as String);
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
