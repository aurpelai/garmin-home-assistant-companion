import Toybox.Lang;

// Pure data + parsing layer. No networking, no UI — this is the unit-tested core.
//
// The combined HA /api/template call returns a JSON object with three keys:
//   { "areas":  { areaName: [entityId, ...], ... },
//     "states": { entityId: true|false, ... },
//     "groups": [entityId, ...] }
// LightSnapshot splits that body, wrapping the areas section into an
// area-ordered structure (from which the flat "all lights" list derives),
// parsing the states section into an entity_id -> Boolean map, and parsing the
// groups section into a set of the light ids that are light groups (used to
// order groups ahead of plain lights in every list view).
//
// Each section degrades independently: non-conforming input yields an empty
// result rather than throwing (watch UX: show "no lights" / all-off, not a
// crash).

class LightSnapshot {
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
    // yields an empty snapshot.
    static function fromTemplateData(data as Dictionary or String or Null) as LightSnapshot {
        if (!(data instanceof Dictionary)) {
            return new LightSnapshot([] as Array<Dictionary>, {} as Dictionary<String, Boolean>,
                                     {} as Dictionary<String, Boolean>);
        }
        var d = data as Dictionary;
        return new LightSnapshot(parseAreas(d.get("areas")), parseStates(d.get("states")),
                                 parseGroups(d.get("groups")));
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    function isOn(entityId as String) as Boolean {
        var v = states.get(entityId);
        return (v == null) ? false : (v as Boolean);
    }

    function isGroup(entityId as String) as Boolean {
        return groups.hasKey(entityId);
    }

    // Deduplicated, group-first-then-alphabetical union of every area's lights —
    // backs the "All lights" view.
    function allLights() as Array<String> {
        var seen = {} as Dictionary<String, Boolean>;
        var flat = [] as Array<String>;
        for (var i = 0; i < areas.size(); i++) {
            var lights = areas[i].get(:lights) as Array<String>;
            for (var j = 0; j < lights.size(); j++) {
                var id = lights[j];
                if (!seen.hasKey(id)) {
                    seen.put(id, true);
                    flat.add(id);
                }
            }
        }
        return orderGroupsFirst(flat);
    }

    function lightsForArea(name as String) as Array<String> {
        for (var i = 0; i < areas.size(); i++) {
            if ((areas[i].get(:name) as String).equals(name)) {
                return orderGroupsFirst(areas[i].get(:lights) as Array<String>);
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
        for (var i = 0; i < ids.size(); i++) {
            if (isGroup(ids[i])) {
                grouped.add(ids[i]);
            } else {
                plain.add(ids[i]);
            }
        }
        var out = sortStrings(grouped);
        out.addAll(sortStrings(plain));
        return out;
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

        for (var i = 0; i < names.size(); i++) {
            var name = names[i] as String;
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
        var d = raw as Dictionary;
        var keys = d.keys();
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i];
            var v = d.get(k);
            if (k instanceof String && v instanceof Boolean) {
                out.put(k as String, v as Boolean);
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
        for (var i = 0; i < ids.size(); i++) {
            out.put(ids[i], true);
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
        var arr = raw as Array;
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] instanceof String) {
                out.add(arr[i] as String);
            }
        }
        return out;
    }

    // Simple insertion sort — device string arrays here are small (areas, lights
    // per area), and Monkey C has no stable built-in sort for arbitrary arrays.
    static function sortStrings(arr as Array<String>) as Array<String> {
        var a = arr.slice(0, null) as Array<String>;
        for (var i = 1; i < a.size(); i++) {
            var key = a[i];
            var j = i - 1;
            while (j >= 0 && compare(a[j], key) > 0) {
                a[j + 1] = a[j];
                j--;
            }
            a[j + 1] = key;
        }
        return a;
    }

    // Lexicographic compare by char code. Monkey C's String has no compareTo,
    // so compare code point by code point. Returns <0, 0, or >0.
    static function compare(x as String, y as String) as Number {
        var xc = x.toCharArray();
        var yc = y.toCharArray();
        var n = (xc.size() < yc.size()) ? xc.size() : yc.size();
        for (var i = 0; i < n; i++) {
            var d = xc[i].toNumber() - yc[i].toNumber();
            if (d != 0) { return d; }
        }
        return xc.size() - yc.size();
    }
}
