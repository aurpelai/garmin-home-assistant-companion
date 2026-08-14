import Toybox.Lang;

// Payload dictionary in, one target's worth of parsed state out. Knows the
// transport's key names and nothing else; HaState knows entities, not that
// lights arrive under a "lights" key from a webhook render.
//
// Every section parses independently: non-conforming input yields an empty
// result rather than throwing, so a bad payload degrades to an empty target
// instead of crashing the watch.
module HaPayload {

    function parseStructure(payload as Object or Null) as ParsedStructure {
        var data = payload instanceof Dictionary ? payload : {};

        return new ParsedStructure(
            asStringOrNull(data.get("zone")),
            parseAreas(data.get("areas")),
            parseFloors(data.get("floors")));
    }

    function parseLights(payload as Object or Null) as ParsedLights {
        var entries = entriesOf(payload, "lights");
        var lights = {} as Dictionary<String, LightModel>;
        var entityIds = entries.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var entry = entries.get(entityId) as Dictionary;
            lights.put(entityId, new LightModel(
                entry.get("state") instanceof Boolean ? entry.get("state") as Boolean : false,
                asStringOrNull(entry.get("name")),
                asAvailable(entry.get("available")),
                asMemberIds(entry.get("memberIds"))));
        }

        return new ParsedLights(lights, groupByArea(entries));
    }

    // A sensor with no state object is absent rather than present with nulls:
    // display_state is the row's only text, so an entry without one cannot be
    // rendered at all.
    function parseSensors(payload as Object or Null) as ParsedSensors {
        var entries = entriesOf(payload, "sensors");
        var sensors = {} as Dictionary<String, SensorModel>;
        var readable = {} as Dictionary<String, Dictionary>;
        var entityIds = entries.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var entry = entries.get(entityId) as Dictionary;
            var displayValue = asStringOrNull(entry.get("display_state"));
            if (displayValue == null) {
                continue;
            }

            sensors.put(entityId, new SensorModel(
                asFloatOrNull(entry.get("state")),
                displayValue,
                asStringOrNull(entry.get("unit")),
                asStringOrNull(entry.get("device_class")),
                asStringOrNull(entry.get("name")),
                asAvailable(entry.get("available"))));
            readable.put(entityId, entry);
        }

        return new ParsedSensors(sensors, groupByArea(readable));
    }

    function entriesOf(payload as Object or Null, key as String) as Dictionary<String, Dictionary> {
        var out = {} as Dictionary<String, Dictionary>;
        if (!(payload instanceof Dictionary)) {
            return out;
        }

        var raw = payload.get(key);
        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var entityIds = raw.keys();
        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index];
            var entry = raw.get(entityId);
            if (entityId instanceof String && entry instanceof Dictionary) {
                out.put(entityId, entry);
            }
        }

        return out;
    }

    function groupByArea(entries as Dictionary<String, Dictionary>) as Dictionary<String, Array<String>> {
        var out = {} as Dictionary<String, Array<String>>;
        var entityIds = entries.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var areaId = asStringOrNull((entries.get(entityId) as Dictionary).get("area_id"));
            if (areaId == null) {
                continue;
            }

            var members = out.get(areaId);
            if (members == null) {
                members = [] as Array<String>;
                out.put(areaId, members);
            }
            members.add(entityId);
        }

        return out;
    }

    // An unnamed area survives with a null name: a naming gap costs a label, not
    // a room.
    function parseAreas(raw as Object or Null) as Dictionary<String, AreaModel> {
        var out = {} as Dictionary<String, AreaModel>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var ids = raw.keys();
        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index];
            var entry = raw.get(id);
            if (id instanceof String && entry instanceof Dictionary) {
                out.put(id, new AreaModel(asStringOrNull(entry.get("name"))));
            }
        }

        return out;
    }

    // Ordered ascending by each floor's `order`, which is Home Assistant's own
    // floors() order; Dictionary.keys() is hash order. The insertion is stable,
    // so equal orders keep parse order.
    function parseFloors(raw as Object or Null) as Array<FloorModel> {
        var out = [] as Array<FloorModel>;
        if (!(raw instanceof Dictionary)) {
            return out;
        }

        var ids = raw.keys();
        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index];
            var entry = raw.get(id);
            if (!(id instanceof String) || !(entry instanceof Dictionary)) {
                continue;
            }

            insertByOrder(out, new FloorModel(
                id,
                asStringOrNull(entry.get("name")),
                asOrder(entry.get("order")),
                onlyStrings(entry.get("areas"))));
        }

        return out;
    }

    function insertByOrder(floors as Array<FloorModel>, floor as FloorModel) as Void {
        var position = floors.size();
        floors.add(floor);

        while (position > 0 && floors[position - 1].order > floor.order) {
            floors[position] = floors[position - 1];
            position--;
        }
        floors[position] = floor;
    }

    // Defaults to available, not off: a missing value is a contract breach and
    // must not mark a working entity down.
    function asAvailable(raw as Object or Null) as Boolean {
        return raw instanceof Boolean ? raw : true;
    }

    function asMemberIds(raw as Object or Null) as Array<String> or Null {
        return raw instanceof Array ? onlyStrings(raw) : null;
    }

    function asFloatOrNull(raw as Object or Null) as Float or Null {
        if (raw instanceof Float) {
            return raw;
        }
        if (raw instanceof Number) {
            return raw.toFloat();
        }
        return null;
    }

    function asStringOrNull(raw as Object or Null) as String or Null {
        return raw instanceof String ? raw : null;
    }

    function asOrder(raw as Object or Null) as Number {
        if (raw instanceof Number) {
            return raw;
        }
        if (raw instanceof Float) {
            return raw.toNumber();
        }
        return 0;
    }

    function onlyStrings(raw as Object or Null) as Array<String> {
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
