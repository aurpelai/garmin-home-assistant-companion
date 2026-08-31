import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module FloorEntityMenuTest {

    function stateOf(lights as Dictionary) as HaState {
        var haState = new HaState();

        haState.setZone(HaPayload.parseZone({
            "areas" => { "area.room" => { "name" => "Room" } },
            "floors" => {
                "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.room"] }
            }
        }));

        haState.setAreas(HaPayload.parseAreas({
            "areas" => { "area.room" => { "name" => "Room" } },
            "floors" => {
                "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.room"] }
            }
        }));

        haState.setFloors(HaPayload.parseFloors({
            "areas" => { "area.room" => { "name" => "Room" } },
            "floors" => {
                "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.room"] }
            }
        }));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));

        return haState;
    }

    function menuOf(haState as HaState) as FloorEntityMenu {
        var model = FloorEntityMenuBuilder.build(haState, "floor.up") as FloorEntityMenuModel;
        return new FloorEntityMenu(new Coordinator(new HaClient(new WebRequestGateway(), new TimerScheduler())), "floor.up", model);
    }
}

(:test)
function aPushMovesTheWholeLightsSwitchWithoutTouchingTheItemSet(logger as Test.Logger) as Boolean {
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
    Test.assertEqual(menu.toServiceTarget(rowId) as String, "floor.up");
    Test.assert(menu.toServiceTarget("light.a") == null);
    return true;
}

(:test)
function aVanishedFloorMakesItsMenuPerish(logger as Test.Logger) as Boolean {
    var menu = FloorEntityMenuTest.menuOf(FloorEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }));

    Test.assert(menu.hasPerished(new HaState()));
    return true;
}

