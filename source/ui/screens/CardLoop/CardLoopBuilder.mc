import Toybox.Lang;

module CardLoopBuilder {

    function build(haState as HaState) as CardLoopModel {
        var cards = [] as Array<Card>;
        var floors = haState.getFloors();

        for (var index = 0; index < floors.size(); index++) {
            var floor = floors[index];
            var floorAreas = filterAreasWithEntities(
                haState, EntitySorter.sortAreas(haState.listVisibleAreasInFloor(floor.id)));
            if (floorAreas.size() == 0) {
                continue;
            }

            cards.add(buildFloorCard(haState, floor.id, floor.name));

            for (var areaIndex = 0; areaIndex < floorAreas.size(); areaIndex++) {
                cards.add(buildAreaCard(haState, floorAreas[areaIndex], floor.id, floor.name));
            }
        }

        var floorlessAreas = filterAreasWithEntities(
            haState, EntitySorter.sortAreas(haState.listVisibleFloorlessAreas()));

        for (var index = 0; index < floorlessAreas.size(); index++) {
            cards.add(buildAreaCard(haState, floorlessAreas[index], null, null));
        }

        if (haState.hasWatchedEntities()) {
            cards.add(buildLabelsCard());
        }

        return new CardLoopModel(cards);
    }

    function buildLabelsCard() as LabelsCard {
        return new LabelsCard();
    }

    function buildAreaCard(haState as HaState, area as AreaModel, floorId as String or Null,
                           floorName as String or Null) as AreaCard {
        return new AreaCard(
            area.id,
            floorId,
            area.name,
            floorName,
            SensorReading.build(haState.getAreaSensorAverages(area.id)),
            ToggleableCount.build(haState.getToggleablesByDomainInArea(area.id, Domain.LIGHT)));
    }

    function buildFloorCard(haState as HaState, floorId as String, floorName as String) as FloorCard {
        return new FloorCard(
            floorId,
            floorName,
            haState.getZone(),
            SensorReading.build(haState.getFloorSensorAverages(floorId)),
            resolveLightSummary(ToggleableCount.build(
                haState.listVisibleToggleablesInFloor(floorId, Domain.LIGHT))));
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
