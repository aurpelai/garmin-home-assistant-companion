import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState.
module CardLoopBuilder {

    function build(haState as HaState) as CardLoopModel {
        var cards = [] as Array<Card>;
        var floors = haState.getFloors();
        var floored = {} as Dictionary<String, Boolean>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            var entities = filterAreasWithEntities(
                haState, EntitySorter.sortAreas(haState.getAreasInFloor(floor.id)));
            if (entities.size() == 0) {
                continue;
            }

            cards.add(buildFloorCard(haState, floor.id, floor.name, entities));

            for (var areaIndex = 0; areaIndex < entities.size(); areaIndex++) {
                floored.put(entities[areaIndex].area.id, true);
                cards.add(buildAreaCard(entities[areaIndex], floor.id, floor.name));
            }
        }

        var areas = haState.getAreas();
        var unfloored = [] as Array<AreaModel>;

        for (var index = 0; index < areas.size(); index++) {
            if (!floored.hasKey(areas[index].id)) {
                unfloored.add(areas[index]);
            }
        }

        var unflooredEntities = filterAreasWithEntities(haState, EntitySorter.sortAreas(unfloored));

        for (var index = 0; index < unflooredEntities.size(); index++) {
            cards.add(buildAreaCard(unflooredEntities[index], null, null));
        }

        return new CardLoopModel(cards);
    }

    function filterAreasWithEntities(haState as HaState,
                                     areas as Array<AreaModel>) as Array<AreaEntities> {
        var filtered = [] as Array<AreaEntities>;

        for (var index = 0; index < areas.size(); index++) {
            var lights = haState.getLightsInArea(areas[index].id);
            var sensors = haState.getSensorsInArea(areas[index].id);

            if (lights.size() > 0 || sensors.size() > 0) {
                filtered.add(new AreaEntities(areas[index], lights, sensors));
            }
        }

        return filtered;
    }

    function buildAreaCard(entities as AreaEntities, floorId as String or Null,
                           floorName as String or Null) as AreaCard {
        var lights = new LightTally();
        lights.addAll(entities.lights);

        return new AreaCard(
            entities.area.id,
            floorId,
            entities.area.name,
            floorName,
            SensorReading.buildFromSensors(entities.sensors),
            lights);
    }

    function buildFloorCard(haState as HaState, floorId as String, floorName as String,
                            areas as Array<AreaEntities>) as FloorCard {
        var lights = new LightTally();
        var sensors = [] as Array<SensorModel>;

        for (var index = 0; index < areas.size(); index++) {
            lights.addAll(areas[index].lights);
            sensors.addAll(areas[index].sensors);
        }

        return new FloorCard(
            floorId,
            floorName,
            haState.getZone(),
            SensorReading.buildFromSensors(sensors),
            lights);
    }
}
