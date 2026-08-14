import Toybox.Lang;

// Pure: touches no platform UI, fetches nothing, and mutates no HaState.
//
// Unlike the per-screen builders this one has no subject to look up, so it takes
// the whole of HaState and always returns a model — an empty home yields an empty
// sequence, which is a finding for the caller rather than an absence.
//
// Each floor heads the run of its own area cards, in Home Assistant's floor
// order. Areas belonging to no floor trail every floor, with no card of their own
// to mark where they begin.
function buildCardLoopModel(haState as HaState) as CardLoopModel {
    var cards = [] as Array<Card>;
    var floors = haState.getFloors();
    var floored = {} as Dictionary<String, Boolean>;

    for (var index = 0; index < floors.size(); index++) {
        var floor = floors[index];
        var areaIds = DisplayOrder.orderAreaIds(haState, floor.areas);
        if (areaIds.size() == 0) {
            continue;
        }

        var floorName = floor.name == null ? floor.id : floor.name as String;
        cards.add(buildFloorCard(haState, floor.id, floorName, areaIds));

        for (var areaIndex = 0; areaIndex < areaIds.size(); areaIndex++) {
            floored.put(areaIds[areaIndex], true);
            cards.add(buildAreaCard(haState, areaIds[areaIndex], floor.id, floorName));
        }
    }

    var unfloored = [] as Array<String>;
    var areaIds = haState.getAreaIds();

    for (var index = 0; index < areaIds.size(); index++) {
        if (!floored.hasKey(areaIds[index])) {
            unfloored.add(areaIds[index]);
        }
    }

    var orderedUnfloored = DisplayOrder.orderAreaIds(haState, unfloored);

    for (var index = 0; index < orderedUnfloored.size(); index++) {
        cards.add(buildAreaCard(haState, orderedUnfloored[index], null, null));
    }

    return new CardLoopModel(cards);
}

function buildAreaCard(haState as HaState, areaId as String, floorId as String or Null,
                       floorName as String or Null) as AreaCard {
    var area = haState.getArea(areaId);
    var lights = new LightTally();
    lights.add(haState, haState.getLightIdsInArea(areaId));

    return new AreaCard(
        areaId,
        floorId,
        area == null || area.name == null ? areaId : area.name as String,
        floorName,
        CardReading.forSensors(haState, haState.getSensorIdsInArea(areaId), false),
        lights);
}

function buildFloorCard(haState as HaState, floorId as String, floorName as String,
                        areaIds as Array<String>) as FloorCard {
    var lights = new LightTally();
    var sensorIds = [] as Array<String>;

    for (var index = 0; index < areaIds.size(); index++) {
        lights.add(haState, haState.getLightIdsInArea(areaIds[index]));
        sensorIds.addAll(haState.getSensorIdsInArea(areaIds[index]));
    }

    return new FloorCard(
        floorId,
        floorName,
        haState.getZone(),
        CardReading.forSensors(haState, sensorIds, true),
        lights);
}
