import Toybox.Lang;

module AreaEntityMenuBuilder {

    function build(haState as HaState, areaId as String) as AreaEntityMenuModel or Null {
        var area = haState.getArea(areaId);
        if (area == null) {
            return null;
        }

        var sortedLights = EntitySorter.sortLights(haState.getLightsInArea(areaId));
        var lights = [] as Array<LightRowModel>;

        for (var index = 0; index < sortedLights.size(); index++) {
            var light = sortedLights[index];

            lights.add(new LightRowModel(
                light.id,
                light.name,
                light.isOn(),
                light.available,
                light.memberIds == null ? null : (light.memberIds as Array<String>).size()));
        }

        var groupedSensors = EntitySorter.groupSensorsByDeviceClass(haState.getSensorsInArea(areaId));
        var sensors = [] as Array<SensorRowModel>;

        for (var index = 0; index < groupedSensors.size(); index++) {
            var sensor = groupedSensors[index];
            sensors.add(new SensorRowModel(sensor.id, sensor.name, sensor.friendlyState, sensor.available));
        }

        return new AreaEntityMenuModel(area.name, lights, sensors);
    }
}
