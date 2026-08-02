import Toybox.Lang;

// Pure parsing layer. Each section parses independently: non-conforming input
// yields an empty result rather than throwing, so a bad payload degrades to an
// empty list and all-off defaults instead of crashing the watch.

class HomeState {
    public var areas as Array<Dictionary>;
    public var states as Dictionary<String, Boolean>;
    private var names as Dictionary<String, String>;
    // A key's presence is the is-a-group signal; its value is the member count.
    private var groups as Dictionary<String, Number>;
    // Separate from states on purpose: on/off and availability are independent.
    private var available as Dictionary<String, Boolean>;
    private var readings as Dictionary<String, Dictionary>;
    private var floors as Array<Dictionary>;
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

    // Build from the already-JSON-parsed "home" value of the webhook
    // response. `data` is the { "areas" => ..., "sensors" => ..., "states" => ...,
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
        return new HomeState(parseAreas(data.get("areas"), data.get("sensors")),
                                 parseBooleanMap(data.get("states")),
                                 parseStringMap(data.get("names")), parseGroups(data.get("groups")),
                                 parseBooleanMap(data.get("available")),
                                 parseReadings(data.get("readings")),
                                 parseFloors(data.get("floors")),
                                 parseStringMap(data.get("kinds")));
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    function isOn(entityId as String) as Boolean {
        var state = states.get(entityId);
        return state == null
            ? false
            : state as Boolean;
    }

    // Defaults to available, not off: a missing entry is a contract breach and
    // must not mark a working light down.
    function isAvailable(entityId as String) as Boolean {
        var value = available.get(entityId);
        return value == null
            ? true
            : value as Boolean;
    }

    function getReading(entityId as String) as String or Null {
        var reading = readings.get(entityId);
        if (reading == null) {
            return null;
        }
        return (reading as Dictionary).get(:display) as String or Null;
    }

    function getReadingValue(entityId as String) as Float or Null {
        var reading = readings.get(entityId);
        if (reading == null) {
            return null;
        }
        return (reading as Dictionary).get(:value) as Float or Null;
    }

    function getReadingUnit(entityId as String) as String or Null {
        var reading = readings.get(entityId);
        if (reading == null) {
            return null;
        }
        return (reading as Dictionary).get(:unit) as String or Null;
    }

    function getKind(entityId as String) as String or Null {
        return kinds.get(entityId);
    }

    // Falls back to the bare id (empty counts as missing) so a row always has a
    // non-blank label; only reachable on a contract breach.
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

    // parseGroups guarantees a present key maps to a non-negative integer, so
    // the bare cast never hits null for a group.
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

    // Every light across the floor's areas, in area order. A floor whose name
    // matches nothing yields an empty list.
    function listLightsInFloor(floorName as String) as Array<String> {
        var out = [] as Array<String>;

        for (var floorIndex = 0; floorIndex < floors.size(); floorIndex++) {
            if (!(floors[floorIndex].get(:name) as String).equals(floorName)) {
                continue;
            }

            var floorAreas = floors[floorIndex].get(:areas) as Array<String>;
            for (var areaIndex = 0; areaIndex < floorAreas.size(); areaIndex++) {
                out.addAll(listLightsInArea(floorAreas[areaIndex]));
            }
        }

        return out;
    }

    // Not sorted: the template already emits an area's sensors grouped by kind.
    function listSensorsInArea(name as String) as Array<String> {
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            if ((areas[areaIndex].get(:name) as String).equals(name)) {
                return areas[areaIndex].get(:sensors) as Array<String>;
            }
        }
        return [] as Array<String>;
    }

    // Areas are re-sorted here rather than trusting input order. Areas on no
    // floor go in a trailing entry whose :name is null.
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
            out.add({
                :id => floor.get(:id) as String,
                :name => floor.get(:name) as String,
                :areas => floorAreas
            });
        }

        var unfloored = [] as Array<String>;
        for (var areaIndex = 0; areaIndex < areas.size(); areaIndex++) {
            var name = areas[areaIndex].get(:name) as String;
            if (!floored.hasKey(name)) {
                unfloored.add(name);
            }
        }
        if (unfloored.size() > 0) {
            out.add({
                :id => null,
                :name => null,
                :areas => sortAreaNames(unfloored)
            });
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

    // Available lights before unavailable, each partition then group-ordered.
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

    // Groups first — they aggregate several lights, so they read as the area's
    // primary controls — then plain lights.
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

    // Sort key is `lowercased-name \n id`: the newline sorts below any printable
    // char, so equal names fall back to the unique id. toLower is ASCII-only, so
    // non-Latin names order by code point, not locale collation.
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

    // Merges the lights and sensors sections into one area-keyed structure; an
    // area survives only if it has at least one light or sensor.
    private static function parseAreas(rawLights as Object or Null,
                                       rawSensors as Object or Null) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;

        if (!(rawLights instanceof Dictionary)) {
            return out;
        }

        var sensorSection = {} as Dictionary;
        if (rawSensors instanceof Dictionary) {
            sensorSection = rawSensors;
        }

        var names = rawLights.keys() as Array<String>;
        names.sort(null);

        for (var index = 0; index < names.size(); index++) {
            var name = names[index] as String;
            var lights = onlyStrings((rawLights as Dictionary).get(name));
            var sensors = onlyStrings(sensorSection.get(name));
            if (lights.size() + sensors.size() > 0) {
                out.add({
                    :name => name,
                    :lights => lights,
                    :sensors => sensors
                });
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

        var entityIds = raw.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var value = raw.get(entityId);
            if (entityId instanceof String && value instanceof Boolean) {
                out.put(entityId, value);
            }
        }

        return out;
    }

    private static function parseStringMap(raw as Object or Null) as Dictionary<String, String> {
        var out = {} as Dictionary<String, String>;

        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var entityIds = raw.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var value = raw.get(entityId);
            if (entityId instanceof String && value instanceof String) {
                out.put(entityId, value);
            }
        }

        return out;
    }

    // A reading with no String display is dropped: display is the row's text,
    // and a missing one can't be rendered.
    private static function parseReadings(raw as Object or Null) as Dictionary<String, Dictionary> {
        var out = {} as Dictionary<String, Dictionary>;

        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var entityIds = raw.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var entry = raw.get(entityId);
            if (!(entityId instanceof String) || !(entry instanceof Dictionary)) {
                continue;
            }
            var display = (entry as Dictionary).get("display");
            if (!(display instanceof String)) {
                continue;
            }
            out.put(entityId as String, {
                :value => toFloatOrZero((entry as Dictionary).get("value")),
                :display => display as String,
                :unit => toStringOrEmpty((entry as Dictionary).get("unit"))
            });
        }

        return out;
    }

    private static function toFloatOrZero(raw as Object or Null) as Float {
        if (raw instanceof Float || raw instanceof Number) {
            return (raw as Number).toFloat();
        }
        return 0.0;
    }

    private static function toStringOrEmpty(raw as Object or Null) as String {
        if (raw instanceof String) {
            return raw;
        }
        return "";
    }

    // Drops any entry without a valid non-negative count: a present key with a
    // null/bad count would later flow into a row sublabel's string concat and
    // throw, so a bad one is degraded to a plain (non-group) row here.
    private static function parseGroups(raw as Object or Null) as Dictionary<String, Number> {
        var out = {} as Dictionary<String, Number>;

        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var entityIds = raw.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var count = raw.get(entityId);
            if (entityId instanceof String && count instanceof Number && (count as Number) >= 0) {
                out.put(entityId, count);
            }
        }

        return out;
    }

    private static function parseFloors(raw as Object or Null) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;

        if (!(raw instanceof Array)) {
            return out;
        }

        for (var index = 0; index < raw.size(); index++) {
            var entry = raw[index];
            if (!(entry instanceof Dictionary)) {
                continue;
            }
            var name = (entry as Dictionary).get("name");
            if (!(name instanceof String)) {
                continue;
            }
            var id = (entry as Dictionary).get("id");
            out.add({
                :id => (id instanceof String) ? id as String : null,
                :name => name as String,
                :areas => onlyStrings((entry as Dictionary).get("areas"))
            });
        }

        return out;
    }

    private static function onlyStrings(raw as Object or Null) as Array<String> {
        var out = [] as Array<String>;

        if (!(raw instanceof Array)) {
            return out;
        }

        for (var index = 0; index < raw.size(); index++) {
            if (raw[index] instanceof String) {
                out.add(raw[index] as String);
            }
        }
        return out;
    }
}
