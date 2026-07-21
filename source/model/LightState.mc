import Toybox.Lang;

// Pure data + parsing layer. No networking, no UI — this is the unit-tested core.
//
// The combined HA /api/template call returns a JSON object with three keys:
//   { "areas":  { areaName: [entityId, ...], ... },
//     "states": { entityId: true|false, ... },
//     "groups": [entityId, ...] }
// LightState splits that body, wrapping the areas section into an
// area-ordered structure (from which the flat "all lights" list derives),
// parsing the states section into an entity_id -> Boolean map, and parsing the
// groups section into a set of the light ids that are light groups (used to
// order groups ahead of plain lights in every list view).
//
// Each section degrades independently: non-conforming input yields an empty
// result rather than throwing (watch UX: show "no lights" / all-off, not a
// crash).

class LightState {
    // Array of { :name => String, :lights => Array<String> }, sorted by area name.
    public var areas as Array<Dictionary>;
    // entity_id -> Boolean (isOn), the server's on/off truth at load time.
    public var states as Dictionary<String, Boolean>;
    // Set of entity_ids that are light groups (value always true; membership is
    // the signal). Backs group-first ordering in the list views.
    private var groups as Dictionary<String, Boolean>;

    function initialize(areas as Array<Dictionary>, states as Dictionary<String, Boolean>,
                        groups as Dictionary<String, Boolean>) {
        self.areas = areas;
        self.states = states;
        self.groups = groups;
    }

    // Build from the already-JSON-parsed body of the combined /api/template
    // response. `data` is what Communications hands the callback for a JSON
    // response: the three-key { "areas" => ..., "states" => ..., "groups" => ... }
    // Dictionary. Each section parses defensively; a missing or malformed body
    // yields an empty LightState.
    static function fromTemplateData(data as Dictionary or String or Null) as LightState {
        if (!(data instanceof Dictionary)) {
            return new LightState([] as Array<Dictionary>, {} as Dictionary<String, Boolean>,
                                     {} as Dictionary<String, Boolean>);
        }
        var body = data as Dictionary;
        return new LightState(parseAreas(body.get("areas")), parseStates(body.get("states")),
                                 parseGroups(body.get("groups")));
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    function isOn(entityId as String) as Boolean {
        var state = states.get(entityId);
        return (state == null) ? false : (state as Boolean);
    }

    function isGroup(entityId as String) as Boolean {
        return groups.hasKey(entityId);
    }

    // Deduplicated, group-first-then-alphabetical union of every area's lights —
    // backs the "All lights" view.
    function allLights() as Array<String> {
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
        return orderGroupsFirst(flat);
    }

    function lightsForArea(name as String) as Array<String> {
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            if ((areas[areaIndex].get(:name) as String).equals(name)) {
                return orderGroupsFirst(areas[areaIndex].get(:lights) as Array<String>);
            }
        }
        return [] as Array<String>;
    }

    // Light groups first (alphabetical among themselves), then plain lights
    // (alphabetical among themselves). Groups aggregate several lights, so they
    // read as the primary controls and belong at the top of every list.
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
        var ordered = sortStrings(grouped);
        ordered.addAll(sortStrings(plain));
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

        var names = (raw as Dictionary).keys();
        names = sortStrings(names as Array<String>);

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

    // The "groups" section: [entityId, ...] -> a set of group ids (value always
    // true). A non-Array or missing value yields an empty set; non-String
    // entries are dropped.
    private static function parseGroups(raw as Object or Null) as Dictionary<String, Boolean> {
        var out = {} as Dictionary<String, Boolean>;
        var ids = onlyStrings(raw);
        for (var index = 0; index < ids.size(); index++) {
            out.put(ids[index], true);
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

    // Simple insertion sort — device string arrays here are small (areas, lights
    // per area), and Monkey C has no stable built-in sort for arbitrary arrays.
    static function sortStrings(strings as Array<String>) as Array<String> {
        var sorted = strings.slice(0, null) as Array<String>;
        for (var index = 1; index < sorted.size(); index++) {
            var key = sorted[index];
            var position = index - 1;
            while (position >= 0 && compare(sorted[position], key) > 0) {
                sorted[position + 1] = sorted[position];
                position--;
            }
            sorted[position + 1] = key;
        }
        return sorted;
    }

    // Lexicographic compare by char code. Monkey C's String has no compareTo,
    // so compare code point by code point. Returns <0, 0, or >0.
    static function compare(first as String, second as String) as Number {
        var firstChars = first.toCharArray();
        var secondChars = second.toCharArray();
        var shared = (firstChars.size() < secondChars.size()) ? firstChars.size() : secondChars.size();
        for (var index = 0; index < shared; index++) {
            var diff = firstChars[index].toNumber() - secondChars[index].toNumber();
            if (diff != 0) { return diff; }
        }
        return firstChars.size() - secondChars.size();
    }
}
