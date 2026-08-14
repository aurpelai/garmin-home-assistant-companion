import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module FloorEntityMenuTest {

    function stateOf(lights as Dictionary) as HaState {
        var haState = new HaState();

        haState.setStructure(HaPayload.parseStructure({
            "areas" => { "area.room" => { "name" => "Room" } },
            "floors" => {
                "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.room"] }
            }
        }));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));

        return haState;
    }

    function menuOf(haState as HaState) as FloorEntityMenu {
        var model = buildFloorEntityMenuModel(haState, "floor.up") as FloorEntityMenuModel;
        return new FloorEntityMenu(new Coordinator(new HaClient()), "floor.up", model);
    }
}

(:test)
function aPushMovesTheWholeLightsSwitchWithoutAddingASecondRow(logger as Test.Logger) as Boolean {
    var menu = FloorEntityMenuTest.menuOf(FloorEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }));

    Test.assert((menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
    Test.assert(menu.getItem(1) == null);

    menu.rebuild(FloorEntityMenuTest.stateOf({
        "light.a" => { "state" => false, "area_id" => "area.room" }
    }));

    Test.assert(!(menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
    Test.assert(menu.getItem(1) == null);
    return true;
}

(:test)
function theWholeLightsRowTargetsTheFloorRatherThanItsOwnId(logger as Test.Logger) as Boolean {
    var menu = FloorEntityMenuTest.menuOf(FloorEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }));
    var rowId = (menu.getItem(0) as WatchUi.MenuItem).getId();

    Test.assertEqual(rowId as String, FloorEntityMenuModel.LIGHTS_ROW_ID);
    Test.assertEqual(menu.serviceTargetOf(rowId) as String, "floor.up");
    Test.assert(menu.serviceTargetOf("light.a") == null);
    return true;
}

(:test)
function aFloorWithNoLightsGetsNoRowRatherThanADeadOne(logger as Test.Logger) as Boolean {
    var menu = FloorEntityMenuTest.menuOf(FloorEntityMenuTest.stateOf({} as Dictionary));

    Test.assert(menu.getItem(0) == null);
    return true;
}

(:test)
function aVanishedFloorReportsItsSubjectGoneRatherThanPushing(logger as Test.Logger) as Boolean {
    var menu = FloorEntityMenuTest.menuOf(FloorEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }));

    Test.assert(menu.rebuild(new HaState()) == false);
    return true;
}

(:test)
function theWholeLightsRowAppearsWhenItsLightsArriveLate(logger as Test.Logger) as Boolean {
    // The floor is known from the structure before any light is, so a menu
    // opened in that window must still gain its row once the lights land.
    var haState = new HaState();
    haState.setStructure(HaPayload.parseStructure({
        "areas" => { "area.room" => { "name" => "Room" } },
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.room"] } }
    }));

    var menu = FloorEntityMenuTest.menuOf(haState);
    Test.assert(menu.getItem(0) == null);

    haState.setLights(HaPayload.parseLights({
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.room" } }
    }));
    menu.rebuild(haState);

    Test.assert((menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
    Test.assertEqual(menu.serviceTargetOf((menu.getItem(0) as WatchUi.MenuItem).getId()) as String,
        "floor.up");
    Test.assert(menu.getItem(1) == null);
    return true;
}
