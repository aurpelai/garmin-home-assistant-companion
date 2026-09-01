import Toybox.Lang;

// Knows the transport's key names so HaState does not: it holds entities, not
// the fact that lights arrive under a "lights" key from a webhook render.
//
// Non-conforming input yields an empty result rather than throwing, so a bad
// payload costs one target rather than crashing the watch.
module HaPayload {

    function parseZone(payload as Object or Null) as String or Null {
        return asStringOrNull(payload instanceof Dictionary ? payload.get("zone") : null);
    }

    function parseLights(payload as Object or Null) as Dictionary<String, LightModel> {
        var entries = readEntries(payload, "lights");
        var lights = {} as Dictionary<String, LightModel>;
        var entityIds = entries.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var entry = entries.get(entityId) as Dictionary;
            lights.put(entityId, new LightModel(
                entityId,
                entry.get("state") instanceof Boolean ? entry.get("state") as Boolean : false,
                asString(entry.get("name")),
                asAvailable(entry.get("available")),
                asStringOrNull(entry.get("area_id")),
                asMemberIds(entry.get("memberIds")),
                asStringOrNull(entry.get("brightness"))));
        }

        return lights;
    }

    function parseFans(payload as Object or Null) as Dictionary<String, FanModel> {
        var entries = readEntries(payload, "fans");
        var fans = {} as Dictionary<String, FanModel>;
        var entityIds = entries.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var entry = entries.get(entityId) as Dictionary;
            fans.put(entityId, new FanModel(
                entityId,
                entry.get("state") instanceof Boolean ? entry.get("state") as Boolean : false,
                asString(entry.get("name")),
                asAvailable(entry.get("available")),
                asStringOrNull(entry.get("area_id")),
                asMemberIds(entry.get("memberIds")),
                asStringOrNull(entry.get("speed"))));
        }

        return fans;
    }

    function parseSensors(payload as Object or Null) as Dictionary<String, SensorModel> {
        var entries = readEntries(payload, "sensors");
        var sensors = {} as Dictionary<String, SensorModel>;
        var entityIds = entries.keys();

        for (var index = 0; index < entityIds.size(); index++) {
            var entityId = entityIds[index] as String;
            var entry = entries.get(entityId) as Dictionary;
            var friendlyState = asStringOrNull(entry.get("friendly_state"));
            if (friendlyState == null) {
                continue;
            }

            sensors.put(entityId, new SensorModel(
                entityId,
                friendlyState,
                asString(entry.get("device_class")),
                asString(entry.get("name")),
                asAvailable(entry.get("available")),
                asStringOrNull(entry.get("area_id"))));
        }

        return sensors;
    }

    function parseAreaLightCounts(payload as Object or Null) as Dictionary<String, LightCount> {
        var entries = readEntries(payload, "areas");
        var out = {} as Dictionary<String, LightCount>;
        var ids = entries.keys();

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index] as String;
            var entry = entries.get(id) as Dictionary;
            out.put(id, new LightCount(
                asNumber(entry.get("on")),
                asNumber(entry.get("available")),
                asNumber(entry.get("unavailable"))));
        }

        return out;
    }

    function parseFloorLightSummaries(payload as Object or Null) as Dictionary<String, String> {
        if (!(payload instanceof Dictionary)) {
            return {} as Dictionary<String, String>;
        }

        var raw = payload.get("floors");
        return raw instanceof Dictionary ? asStringMap(raw) : ({} as Dictionary<String, String>);
    }

    function parseHomeLightSummary(payload as Object or Null) as String or Null {
        return asStringOrNull(payload instanceof Dictionary ? payload.get("home") : null);
    }

    function parseAverages(payload as Object or Null, key as String)
            as Dictionary<String, Dictionary<String, String>> {
        var entries = readEntries(payload, key);
        var out = {} as Dictionary<String, Dictionary<String, String>>;
        var ids = entries.keys();

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index] as String;
            out.put(id, asStringMap(entries.get(id) as Dictionary));
        }

        return out;
    }

    function parseHomeAverages(payload as Object or Null) as Dictionary<String, String> {
        if (!(payload instanceof Dictionary)) {
            return {} as Dictionary<String, String>;
        }

        var raw = payload.get("home");
        return raw instanceof Dictionary ? asStringMap(raw) : ({} as Dictionary<String, String>);
    }

    function asStringMap(raw as Dictionary) as Dictionary<String, String> {
        var out = {} as Dictionary<String, String>;
        var keys = raw.keys();

        for (var index = 0; index < keys.size(); index++) {
            var key = keys[index];
            var value = asStringOrNull(raw.get(key));
            if (key instanceof String && value != null) {
                out.put(key, value);
            }
        }

        return out;
    }

    function readEntries(payload as Object or Null, key as String) as Dictionary<String, Dictionary> {
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

    function parseAreas(payload as Object or Null) as Dictionary<String, AreaModel> {
        var entries = readEntries(payload, "areas");
        var out = {} as Dictionary<String, AreaModel>;
        var ids = entries.keys();

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index] as String;
            var entry = entries.get(id) as Dictionary;
            out.put(id, new AreaModel(id, asString(entry.get("name"))));
        }

        return out;
    }

    // UNVERIFIED: ordered ascending by each floor's `order`, which is Home
    // Assistant's own floors() order; Dictionary.keys() is hash order. The
    // insertion is stable, so equal orders keep parse order.
    function parseFloors(payload as Object or Null) as Array<FloorModel> {
        var entries = readEntries(payload, "floors");
        var out = [] as Array<FloorModel>;
        var ids = entries.keys();

        for (var index = 0; index < ids.size(); index++) {
            var id = ids[index] as String;
            var entry = entries.get(id) as Dictionary;

            insertFloorByOrder(out, new FloorModel(
                id,
                asString(entry.get("name")),
                asNumber(entry.get("order")),
                onlyStrings(entry.get("areas"))));
        }

        return out;
    }

    function insertFloorByOrder(floors as Array<FloorModel>, floor as FloorModel) as Void {
        var position = floors.size();
        floors.add(floor);

        while (position > 0 && floors[position - 1].order > floor.order) {
            floors[position] = floors[position - 1];
            position--;
        }
        floors[position] = floor;
    }

    function asAvailable(raw as Object or Null) as Boolean {
        return raw instanceof Boolean ? raw : true;
    }

    function asMemberIds(raw as Object or Null) as Array<String> or Null {
        return raw instanceof Array ? onlyStrings(raw) : null;
    }

    function asStringOrNull(raw as Object or Null) as String or Null {
        return raw instanceof String ? raw : null;
    }

    // UNVERIFIED: Home Assistant guarantees the values read this way, so a
    // non-string only reaches here on a malformed payload, which must not throw.
    function asString(raw as Object or Null) as String {
        return raw instanceof String ? raw : "";
    }

    function asNumber(raw as Object or Null) as Number {
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
