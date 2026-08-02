import Toybox.Lang;

// Pure parsing layer. Each section parses independently: non-conforming input
// yields an empty result rather than throwing, so a bad payload degrades to an
// empty list and all-off defaults instead of crashing the watch.

class HomeState {
    public var areas as Dictionary<String, Dictionary>;
    private var _lights as Dictionary<String, Dictionary>;
    private var _sensors as Dictionary<String, Dictionary>;
    private var _floors as Array<Dictionary>;

    function initialize(areas as Dictionary<String, Dictionary>, lights as Dictionary<String, Dictionary>,
                        sensors as Dictionary<String, Dictionary>, floors as Array<Dictionary>) {
        self.areas = areas;
        self._lights = lights;
        self._sensors = sensors;
        self._floors = floors;
    }

    // Build from the already-JSON-parsed "home" value of the webhook response.
    // `data` is the { "lights" => ..., "sensors" => ..., "areas" => ...,
    // "floors" => ... } Dictionary, each section self-contained and keyed by
    // entity/area/floor id. Each section parses defensively; a missing or
    // malformed body yields an empty HomeState.
    static function fromTemplateData(data as Dictionary or String or Null) as HomeState {
        if (!(data instanceof Dictionary)) {
            return new HomeState({} as Dictionary<String, Dictionary>, {} as Dictionary<String, Dictionary>,
                                     {} as Dictionary<String, Dictionary>, [] as Array<Dictionary>);
        }
        var lights = parseEntityMap(data.get("lights"), false);
        var sensors = parseEntityMap(data.get("sensors"), true);
        return new HomeState(parseAreas(data.get("areas")), lights, sensors,
                                 parseFloors(data.get("floors")));
    }

    function isEmpty() as Boolean {
        return areas.size() == 0;
    }

    function isOn(entityId as String) as Boolean {
        var light = _lights.get(entityId);
        if (light == null) {
            return false;
        }
        return (light as Dictionary).get(:state) as Boolean;
    }

    function lightIds() as Array<String> {
        return _lights.keys();
    }

    function hasLight(entityId as String) as Boolean {
        return _lights.hasKey(entityId);
    }

    // Defaults to available, not off: a missing entry is a contract breach and
    // must not mark a working light down.
    function isAvailable(entityId as String) as Boolean {
        var entity = entityFor(entityId);
        if (entity == null) {
            return true;
        }
        var value = (entity as Dictionary).get(:available);
        return value == null
            ? true
            : value as Boolean;
    }

    function getReading(entityId as String) as String or Null {
        var sensor = _sensors.get(entityId);
        if (sensor == null) {
            return null;
        }
        return (sensor as Dictionary).get(:display_state) as String or Null;
    }

    // A sensor's `state` slot is polymorphic (parseEntity stores a Boolean for a
    // non-numeric state, as lights need). Only a genuine number is a reading
    // value, so a Boolean returns null rather than poisoning the numeric mean.
    function getReadingValue(entityId as String) as Float or Null {
        var sensor = _sensors.get(entityId);
        if (sensor == null) {
            return null;
        }
        var state = (sensor as Dictionary).get(:state);
        if (state instanceof Float || state instanceof Number) {
            return state as Float;
        }
        return null;
    }

    function getReadingUnit(entityId as String) as String or Null {
        var sensor = _sensors.get(entityId);
        if (sensor == null) {
            return null;
        }
        return (sensor as Dictionary).get(:unit) as String or Null;
    }

    function getDeviceClass(entityId as String) as String or Null {
        var sensor = _sensors.get(entityId);
        if (sensor == null) {
            return null;
        }
        return (sensor as Dictionary).get(:device_class) as String or Null;
    }

    // Falls back to the bare id (empty counts as missing) so a row always has a
    // non-blank label; only reachable on a contract breach.
    function getName(entityId as String) as String {
        var entity = entityFor(entityId);
        var name = entity == null ? null : (entity as Dictionary).get(:name);
        if (name == null || (name as String).equals("")) {
            return entityId;
        }
        return name as String;
    }

    function isGroup(entityId as String) as Boolean {
        var light = _lights.get(entityId);
        return light != null && (light as Dictionary).hasKey(:memberCount);
    }

    // parseLights/parseSensors guarantee a present memberCount maps to a
    // non-negative integer, so the bare cast never hits null for a group.
    function getMemberCount(entityId as String) as Number {
        return (_lights.get(entityId) as Dictionary).get(:memberCount) as Number;
    }

    function listLightsInArea(areaId as String) as Array<String> {
        var area = areaFor(areaId);
        if (area == null) {
            return [] as Array<String>;
        }
        return orderAvailableFirst(area.get(:lights) as Array<String>);
    }

    // Every light across the floor's areas, in area order. A floor whose id
    // matches nothing yields an empty list.
    function listLightsInFloor(floorId as String) as Array<String> {
        var out = [] as Array<String>;

        for (var floorIndex = 0; floorIndex < _floors.size(); floorIndex++) {
            var floorIdValue = _floors[floorIndex].get(:id);
            if (floorIdValue == null || !(floorIdValue as String).equals(floorId)) {
                continue;
            }

            var floorAreas = _floors[floorIndex].get(:areas) as Array<String>;
            for (var areaIndex = 0; areaIndex < floorAreas.size(); areaIndex++) {
                out.addAll(listLightsInArea(floorAreas[areaIndex]));
            }
        }

        return out;
    }

    // Not sorted: the template already emits an area's sensors grouped by
    // device_class.
    function listSensorsInArea(areaId as String) as Array<String> {
        var area = areaFor(areaId);
        if (area == null) {
            return [] as Array<String>;
        }
        return area.get(:sensors) as Array<String>;
    }

    // Floors come out in HA's own floors() order (basement-up); parseFloors
    // already ordered `_floors` by each floor's numeric order. Areas within a
    // floor are re-sorted rather than trusting input order. Areas on no floor
    // go in a trailing entry whose :id and :name are null.
    function buildFloors() as Array<Dictionary> {
        var floored = {} as Dictionary<String, Boolean>;
        var out = [] as Array<Dictionary>;

        for (var floorIndex = 0; floorIndex < _floors.size(); floorIndex++) {
            var floor = _floors[floorIndex];
            var floorAreas = sortAreaIds(floor.get(:areas) as Array<String>);
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
        var areaIds = areas.keys();
        for (var areaIndex = 0; areaIndex < areaIds.size(); areaIndex++) {
            var id = areaIds[areaIndex] as String;
            if (!floored.hasKey(id)) {
                unfloored.add(id);
            }
        }
        if (unfloored.size() > 0) {
            out.add({
                :id => null,
                :name => null,
                :areas => sortAreaIds(unfloored)
            });
        }

        return out;
    }

    function getAreaName(areaId as String) as String {
        var area = areaFor(areaId);
        if (area == null) {
            return areaId;
        }
        return area.get(:name) as String;
    }

    private function entityFor(entityId as String) as Dictionary or Null {
        var light = _lights.get(entityId);
        if (light != null) {
            return light as Dictionary;
        }
        return _sensors.get(entityId) as Dictionary or Null;
    }

    private function areaFor(areaId as String) as Dictionary or Null {
        return areas.get(areaId) as Dictionary or Null;
    }

    // Order area ids by their display name alphabetically, case-insensitively.
    // Only areas that actually hold entities (present in `areas`) are kept — a
    // floor's areas list may name an area the areas section dropped for
    // holding neither.
    private function sortAreaIds(ids as Array<String>) as Array<String> {
        var kept = [] as Array<String>;
        for (var index = 0; index < ids.size(); index++) {
            if (hasArea(ids[index])) {
                kept.add(ids[index]);
            }
        }

        return sortByLabel(kept, method(:getAreaName));
    }

    private function hasArea(areaId as String) as Boolean {
        return areas.hasKey(areaId);
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

    private function sortByName(ids as Array<String>) as Array<String> {
        return sortByLabel(ids, method(:getName));
    }

    // Sort key is `lowercased-label \n id`: the newline sorts below any printable
    // char, so equal labels fall back to the unique id. toLower is ASCII-only, so
    // non-Latin labels order by code point, not locale collation.
    private function sortByLabel(ids as Array<String>, labelFn as Lang.Method) as Array<String> {
        var idForKey = {} as Dictionary<String, String>;
        var keys = [] as Array<String>;
        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index];
            var key = (labelFn.invoke(id) as String).toLower() + "\n" + id;
            idForKey.put(key, id);
            keys.add(key);
        }

        keys.sort(null);

        var ordered = [] as Array<String>;
        for (var index = 0; index < keys.size(); index++) {
            ordered.add(idForKey.get(keys[index]) as String);
        }
        return ordered;
    }

    // Areas keyed by area id -> { name, lights: [entity ids], sensors: [entity
    // ids] }. An area survives only if it has at least one light or sensor.
    private static function parseAreas(raw as Object or Null) as Dictionary<String, Dictionary> {
        var out = {} as Dictionary<String, Dictionary>;

        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var ids = raw.keys();

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index];
            var entry = (raw as Dictionary).get(id);
            if (!(id instanceof String) || !(entry instanceof Dictionary)) {
                continue;
            }
            var name = (entry as Dictionary).get("name");
            if (!(name instanceof String)) {
                continue;
            }
            var lights = onlyStrings((entry as Dictionary).get("lights"));
            var sensors = onlyStrings((entry as Dictionary).get("sensors"));
            if (lights.size() + sensors.size() > 0) {
                out.put(id as String, {
                    :name => name as String,
                    :lights => lights,
                    :sensors => sensors
                });
            }
        }

        return out;
    }

    // An entity section (lights or sensors): entity id -> its attribute object.
    // Drops any entry whose id is not a String or whose value is not a
    // Dictionary; per-field validation happens at the accessor. When
    // requireDisplayState is set (sensors), an entry with no String
    // display_state is dropped: display_state is the row's text and a missing
    // one can't be rendered.
    private static function parseEntityMap(raw as Object or Null,
                                           requireDisplayState as Boolean) as Dictionary<String, Dictionary> {
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
            if (requireDisplayState && !((entry as Dictionary).get("display_state") instanceof String)) {
                continue;
            }
            out.put(entityId as String, parseEntity(entry as Dictionary));
        }

        return out;
    }

    // `state` is polymorphic across sections (boolean for lights, float for
    // sensors); a value of neither type degrades to `false` rather than being
    // dropped, since isOn's off default already treats absent as off.
    private static function parseEntity(entry as Dictionary) as Dictionary {
        var state = entry.get("state");
        var out = {
            :name => toStringOrNull(entry.get("name")),
            :available => entry.get("available") instanceof Boolean ? entry.get("available") as Boolean : true
        } as Dictionary;

        if (state instanceof Boolean) {
            out.put(:state, state as Boolean);
        } else if (state instanceof Float || state instanceof Number) {
            out.put(:state, (state as Number).toFloat());
        } else {
            out.put(:state, false);
        }

        var displayState = entry.get("display_state");
        if (displayState instanceof String) {
            out.put(:display_state, displayState as String);
        }

        var unit = entry.get("unit");
        if (unit instanceof String) {
            out.put(:unit, unit as String);
        }

        var deviceClass = entry.get("device_class");
        if (deviceClass instanceof String) {
            out.put(:device_class, deviceClass as String);
        }

        var memberCount = entry.get("memberCount");
        if (memberCount instanceof Number && (memberCount as Number) >= 0) {
            out.put(:memberCount, memberCount as Number);
        }

        return out;
    }

    private static function toStringOrNull(raw as Object or Null) as String or Null {
        if (raw instanceof String) {
            return raw;
        }
        return null;
    }

    // Ordered ascending by each floor's numeric `order` (HA's floors() order,
    // basement-up), since Dictionary.keys() is hash order. The insertion is
    // stable, so equal orders keep parse order.
    private static function parseFloors(raw as Object or Null) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;

        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var orders = [] as Array<Number>;
        var ids = raw.keys();

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index];
            var entry = (raw as Dictionary).get(id);
            if (!(id instanceof String) || !(entry instanceof Dictionary)) {
                continue;
            }
            var name = (entry as Dictionary).get("name");
            if (!(name instanceof String)) {
                continue;
            }

            var order = floorOrder((entry as Dictionary).get("order"));
            var floor = {
                :id => id as String,
                :name => name as String,
                :areas => onlyStrings((entry as Dictionary).get("areas"))
            };

            out.add(floor);
            orders.add(order);
            var position = out.size() - 1;
            while (position > 0 && orders[position - 1] > order) {
                out[position] = out[position - 1];
                orders[position] = orders[position - 1];
                position--;
            }
            out[position] = floor;
            orders[position] = order;
        }

        return out;
    }

    private static function floorOrder(raw as Object or Null) as Number {
        if (raw instanceof Number) {
            return raw;
        }
        if (raw instanceof Float) {
            return raw.toNumber();
        }
        return 0;
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
