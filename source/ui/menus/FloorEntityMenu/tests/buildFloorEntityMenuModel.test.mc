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
function aFloorWithNothingCommandableCarriesNoRowAtAll(logger as Test.Logger) as Boolean {
    // The menu carries an item per domain present on the floor and omits the
    // rest, so a floor whose only lights are a group and a dead bulb gets no
    // row rather than one that commands nothing.
    var haState = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.grp" => { "state" => true, "area_id" => "area.room", "available" => true,
                "memberIds" => ["light.dead"] },
            "light.dead" => { "state" => false, "area_id" => "area.room", "available" => false }
        });

    Test.assertEqual(
        (buildFloorEntityMenuModel(haState, "floor.g") as FloorEntityMenuModel).lights.size(), 0);
    return true;
}

(:test)
function theFloorRowTargetsTheFloorRatherThanItsOwnRowId(logger as Test.Logger) as Boolean {
    // Row identity and service target coincide on an entity row and diverge
    // here: Home Assistant expands the floor id server-side.
    var haState = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.a" => { "state" => false, "area_id" => "area.room", "available" => true }
        });
    var row = (buildFloorEntityMenuModel(haState, "floor.g") as FloorEntityMenuModel).lights[0];

    Test.assertEqual(row.serviceTarget, "floor.g");
    Test.assert(!row.rowId.equals(row.serviceTarget));
    return true;
}

(:test)
function theFloorRowReadsOnWhenAnyCommandableLightIsOn(logger as Test.Logger) as Boolean {
    // Judged over exactly the scope a tap would command — groups and dead lights
    // excluded — so the row cannot claim a state its own action would not reach.
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

(:test)
function theFloorRowIsPendingWhileAnyMemberOfItsScopeIs(logger as Test.Logger) as Boolean {
    // A floor action creates one override per member, so the row's status has to
    // read the same scope: whatever created the override, the row is covered.
    var haState = FloorEntityMenuModelTest.stateOf(
        FloorEntityMenuModelTest.oneFloorWith(["area.room"]), {
            "light.a" => { "state" => false, "area_id" => "area.room", "available" => true },
            "light.b" => { "state" => false, "area_id" => "area.room", "available" => true }
        });

    Test.assert(!(buildFloorEntityMenuModel(haState, "floor.g") as FloorEntityMenuModel).lights[0].isPending);

    haState.override("light.b", true);

    Test.assert((buildFloorEntityMenuModel(haState, "floor.g") as FloorEntityMenuModel).lights[0].isPending);
    return true;
}
