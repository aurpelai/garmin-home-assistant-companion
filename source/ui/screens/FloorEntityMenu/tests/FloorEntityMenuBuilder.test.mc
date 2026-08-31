import Toybox.Lang;
import Toybox.Test;

(:test)
module FloorEntityMenuModelTest {

    function stateOf(structure as Dictionary, lights as Dictionary) as HaState {
        var haState = new HaState();
        haState.setZone(HaPayload.parseZone(structure));
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        return haState;
    }

    function oneFloorWith(areaIds as Array<String>) as Dictionary {
        return {
            "areas" => { "area.room" => { "name" => "Room" } },
            "floors" => { "floor.g" => { "name" => "Ground", "order" => 0, "areas" => areaIds } }
        };
    }
}

(:test)
function aFloorGoneFromTheStructureYieldsNoModel(logger as Test.Logger) as Boolean {
    var haState = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {} as Dictionary);

    Test.assert(FloorEntityMenuBuilder.build(haState, "floor.deleted") == null);
    Test.assert(FloorEntityMenuBuilder.build(haState, "floor.g") != null);
    return true;
}

(:test)
function aFloorWithNoLightsCarriesNoRowWhileOneWithOnlyDeadOnesDoes(logger as Test.Logger) as Boolean {
    var empty = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {} as Dictionary);
    var onlyDead = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
        });

    Test.assertEqual(
        (FloorEntityMenuBuilder.build(empty, "floor.g") as FloorEntityMenuModel).lights.size(), 0);
    Test.assertEqual(
        (FloorEntityMenuBuilder.build(onlyDead, "floor.g") as FloorEntityMenuModel).lights.size(), 1);
    return true;
}

(:test)
function theFloorRowReadsOnWhenAnyLightInTheFloorIsOn(logger as Test.Logger) as Boolean {
    var haState = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.off" => { "state" => false, "area_id" => "area.room", "available" => true },
            "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
        });

    Test.assert(!(FloorEntityMenuBuilder.build(haState, "floor.g") as FloorEntityMenuModel).lights[0].isOn);

    haState.override("light.off", true);

    Test.assert((FloorEntityMenuBuilder.build(haState, "floor.g") as FloorEntityMenuModel).lights[0].isOn);
    return true;
}

