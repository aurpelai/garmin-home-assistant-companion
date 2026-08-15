import Toybox.Lang;
import Toybox.Test;

(:test)
module FloorEntityMenuModelTest {

    function stateOf(structure as Dictionary, lights as Dictionary) as HaState {
        var haState = new HaState();
        haState.setStructure(HaPayload.parseStructure(structure));
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

    Test.assert(buildFloorEntityMenuModel(haState, "floor.deleted") == null);
    Test.assert(buildFloorEntityMenuModel(haState, "floor.g") != null);
    return true;
}

(:test)
function aFloorWithNoLightsCarriesNoRowWhileOneWithOnlyDeadOnesDoes(logger as Test.Logger) as Boolean {
    // The menu carries an item per domain present on the floor and omits the
    // rest, and presence is the only test: a dead bulb is still a light the call
    // reaches, so only a floor with none at all loses the row.
    var empty = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {} as Dictionary);
    var onlyDead = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
        });

    Test.assertEqual(
        (buildFloorEntityMenuModel(empty, "floor.g") as FloorEntityMenuModel).lights.size(), 0);
    Test.assertEqual(
        (buildFloorEntityMenuModel(onlyDead, "floor.g") as FloorEntityMenuModel).lights.size(), 1);
    return true;
}

(:test)
function theFloorRowReadsOnWhenAnyLightInTheFloorIsOn(logger as Test.Logger) as Boolean {
    // Read over exactly the scope a tap commands — every light in the floor — so
    // the row cannot claim a state its own action would not produce.
    var haState = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.off" => { "state" => false, "area_id" => "area.room", "available" => true },
            "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
        });

    Test.assert(!(buildFloorEntityMenuModel(haState, "floor.g") as FloorEntityMenuModel).lights[0].isOn);

    haState.override("light.off", true);

    Test.assert((buildFloorEntityMenuModel(haState, "floor.g") as FloorEntityMenuModel).lights[0].isOn);
    return true;
}

