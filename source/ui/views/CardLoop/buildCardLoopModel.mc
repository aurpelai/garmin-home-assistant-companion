import Toybox.Lang;

// Pure: touches no WatchUi, fetches nothing, and mutates no HaState.
//
// Alone among the builders it has no subject to look up, so it never returns
// null — an empty home yields an empty sequence, a finding rather than an
// absence. Areas belonging to no floor trail every floor, with no card marking
// where they begin.
function buildCardLoopModel(haState as HaState) as CardLoopModel {
    var cards = [] as Array<Card>;
    var floors = haState.getFloors();
    var floored = {} as Dictionary<String, Boolean>;

    for (var index = 0; index < floors.size(); index++) {
        var floor = floors[index];
        var areaIds = DisplayOrder.orderAreaIds(haState, occupiedAreaIds(haState, floor.areas));
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

    var orderedUnfloored = DisplayOrder.orderAreaIds(haState, occupiedAreaIds(haState, unfloored));

    for (var index = 0; index < orderedUnfloored.size(); index++) {
        cards.add(buildAreaCard(haState, orderedUnfloored[index], null, null));
    }

    return new CardLoopModel(cards);
}

// An unavailable entity still counts: a room vanishing because a sensor's
// battery died would be alarming, where a room showing an unavailable reading
// says what is wrong.
function occupiedAreaIds(haState as HaState, areaIds as Array<String>) as Array<String> {
    var occupied = [] as Array<String>;

    for (var index = 0; index < areaIds.size(); index++) {
        var areaId = areaIds[index];

        if (haState.getLightIdsInArea(areaId).size() > 0 || haState.getSensorIdsInArea(areaId).size() > 0) {
            occupied.add(areaId);
        }
    }

    return occupied;
}

function buildAreaCard(haState as HaState, areaId as String, floorId as String or Null,
                       floorName as String or Null) as AreaCard {
    var area = haState.getArea(areaId);
    var lights = new LightTally();
    lights.addAll(haState, haState.getLightIdsInArea(areaId));

    return new AreaCard(
        areaId,
        floorId,
        area == null || area.name == null ? areaId : area.name as String,
        floorName,
        CardReading.forSensors(haState, haState.getSensorIdsInArea(areaId)),
        lights);
}

function buildFloorCard(haState as HaState, floorId as String, floorName as String,
                        areaIds as Array<String>) as FloorCard {
    var lights = new LightTally();
    var sensorIds = [] as Array<String>;

    for (var index = 0; index < areaIds.size(); index++) {
        lights.addAll(haState, haState.getLightIdsInArea(areaIds[index]));
        sensorIds.addAll(haState.getSensorIdsInArea(areaIds[index]));
    }

    return new FloorCard(
        floorId,
        floorName,
        haState.getZone(),
        CardReading.forSensors(haState, sensorIds),
        lights);
}
