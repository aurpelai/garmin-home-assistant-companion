import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState.
module AreaEntityMenuBuilder {

    // Takes the area id and looks the area up, so absence is discovered and
    // answered here rather than at every call site. Returns null when the area is
    // gone.
    function build(haState as HaState, areaId as String) as AreaEntityMenuModel or Null {
        var area = haState.getArea(areaId);
        if (area == null) {
            return null;
        }

        var lightIds = EntitySorter.sortLights(haState, haState.getLightIdsInArea(areaId));
        var lights = [] as Array<LightRowModel>;

        for (var index = 0; index < lightIds.size(); index++) {
            var entityId = lightIds[index];
            var light = haState.getLight(entityId);
            if (light == null) {
                continue;
            }

            lights.add(new LightRowModel(
                entityId,
                light.name,
                haState.isOn(entityId),
                light.available,
                light.memberIds == null ? null : (light.memberIds as Array<String>).size()));
        }

        var sensorIds = EntitySorter.groupSensorsByDeviceClass(haState, haState.getSensorIdsInArea(areaId));
        var sensors = [] as Array<SensorRowModel>;

        for (var index = 0; index < sensorIds.size(); index++) {
            var entityId = sensorIds[index];
            var sensor = haState.getSensor(entityId);
            if (sensor == null) {
                continue;
            }

            sensors.add(new SensorRowModel(entityId, sensor.name, sensor.displayValue, sensor.available));
        }

        return new AreaEntityMenuModel(area.name == null ? areaId : area.name as String, lights, sensors);
    }
}
