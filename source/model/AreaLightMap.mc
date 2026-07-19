import Toybox.Lang;

// Pure data + parsing layer. No networking, no UI — this is the unit-tested core.
//
// The HA /api/template call returns a JSON object shaped { areaName: [entityId, ...] }.
// AreaLightMap wraps that into an area-ordered structure and can derive the
// flat "all lights" list.

class AreaLightMap {
    // Array of { :name => String, :lights => Array<String> }, sorted by area name.
    public var areas as Array<Dictionary>;

    function initialize(areas as Array<Dictionary>) {
        self.areas = areas;
    }

    // Build from the already-JSON-parsed body of the /api/template response.
    // `data` is what Communications hands the callback for a JSON response:
    // a Dictionary<String, Array<String>>. Non-conforming input yields an
    // empty map rather than throwing (watch UX: show "no lights", not a crash).
    static function fromTemplateData(data as Dictionary or String or Null) as AreaLightMap {
        var out = [] as Array<Dictionary>;
        if (!(data instanceof Dictionary)) {
            return new AreaLightMap(out);
        }

        var names = (data as Dictionary).keys();
        names = sortStrings(names as Array<String>);

        for (var i = 0; i < names.size(); i++) {
            var name = names[i] as String;
            var raw = (data as Dictionary).get(name);
            var lights = onlyStrings(raw);
            if (lights.size() > 0) {
                out.add({ :name => name, :lights => lights });
            }
        }
        return new AreaLightMap(out);
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    // Deduplicated, sorted union of every area's lights — backs the "All lights" view.
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
        return sortStrings(flat);
    }

    function lightsForArea(name as String) as Array<String> {
        for (var i = 0; i < areas.size(); i++) {
            if ((areas[i].get(:name) as String).equals(name)) {
                return areas[i].get(:lights) as Array<String>;
            }
        }
        return [] as Array<String>;
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
