import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState.
module CardLoopBuilder {

    function build(haState as HaState) as CardLoopModel {
        var cards = [] as Array<Card>;
        var floors = haState.getFloors();
        var floored = {} as Dictionary<String, Boolean>;

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            var floorAreas = filterAreasWithEntities(
                haState, EntitySorter.sortAreas(haState.getAreasInFloor(floor.id)));
            if (floorAreas.size() == 0) {
                continue;
            }

            cards.add(buildFloorCard(haState, floor.id, floor.name));

            for (var areaIndex = 0; areaIndex < floorAreas.size(); areaIndex++) {
                floored.put(floorAreas[areaIndex].id, true);
                cards.add(buildAreaCard(haState, floorAreas[areaIndex], floor.id, floor.name));
            }
        }

        var areas = haState.getAreas();
        var unfloored = [] as Array<AreaModel>;

        for (var index = 0; index < areas.size(); index++) {
            if (!floored.hasKey(areas[index].id)) {
                unfloored.add(areas[index]);
            }
        }

        var unflooredAreas = filterAreasWithEntities(haState, EntitySorter.sortAreas(unfloored));

        for (var index = 0; index < unflooredAreas.size(); index++) {
            cards.add(buildAreaCard(haState, unflooredAreas[index], null, null));
        }

        return new CardLoopModel(cards);
    }

    function filterAreasWithEntities(haState as HaState, areas as Array<AreaModel>) as Array<AreaModel> {
        var filtered = [] as Array<AreaModel>;

        for (var index = 0; index < areas.size(); index++) {
            if (haState.hasEntitiesInArea(areas[index].id)) {
                filtered.add(areas[index]);
            }
        }

        return filtered;
    }

    function buildAreaCard(haState as HaState, area as AreaModel, floorId as String or Null,
                           floorName as String or Null) as AreaCard {
        return new AreaCard(
            area.id,
            floorId,
            area.name,
            floorName,
            SensorReading.build(haState.getAreaSensorAverages(area.id)),
            ToggleableCount.build(haState.getToggleablesInArea(area.id, Domain.LIGHT)));
    }

    function buildFloorCard(haState as HaState, floorId as String, floorName as String) as FloorCard {
        return new FloorCard(
            floorId,
            floorName,
            haState.getZone(),
            SensorReading.build(haState.getFloorSensorAverages(floorId)),
            resolveLightSummary(ToggleableCount.build(
                haState.getToggleablesInFloor(floorId, Domain.LIGHT))));
    }

    function resolveLightSummary(count as ToggleableCount) as String or Null {
        if (count.available == 0) {
            return null;
        }

        if (count.on == count.available) {
            return LightSummary.ALL_ON;
        }

        if (count.on == 0) {
            return LightSummary.ALL_OFF;
        }

        return LightSummary.SOME_ON;
    }
}
