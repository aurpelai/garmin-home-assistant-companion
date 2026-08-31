import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

(:test)
module AreaEntityMenuTest {

    function stateOf(lights as Dictionary, sensors as Dictionary) as HaState {
        var haState = new HaState();

        haState.setZone(HaPayload.parseZone({
            "areas" => { "area.room" => { "name" => "Room" } }
        }));

        haState.setAreas(HaPayload.parseAreas({
            "areas" => { "area.room" => { "name" => "Room" } }
        }));

        haState.setFloors(HaPayload.parseFloors({
            "areas" => { "area.room" => { "name" => "Room" } }
        }));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));

        return haState;
    }

    function menuOf(haState as HaState) as AreaEntityMenu {
        var model = AreaEntityMenuBuilder.build(haState, "area.room") as AreaEntityMenuModel;
        return new AreaEntityMenu(new Coordinator(new HaClient(new WebRequestSender())), "area.room", model);
    }

    function itemOf(menu as AreaEntityMenu, rowId as String) as WatchUi.MenuItem {
        return menu.getItem(menu.findItemById(rowId)) as WatchUi.MenuItem;
    }
}

(:test)
function aPushChangesTheItemSetInNeitherDirection(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" },
        "light.b" => { "state" => true, "area_id" => "area.room" }
    }, {} as Dictionary));

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.a");
    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getId() as String, "light.b");
    Test.assert(menu.getItem(2) == null);

    menu.rebuild(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => false, "area_id" => "area.room" },
        "light.c" => { "state" => true, "area_id" => "area.room" }
    }, {} as Dictionary));

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.a");
    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getId() as String, "light.b");
    Test.assert(menu.getItem(2) == null);
    return true;
}

(:test)
function anEntityMissingFromTheModelKeepsTheItemItHad(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" },
        "light.gone" => { "state" => true, "area_id" => "area.room", "name" => "Gone" }
    }, {} as Dictionary));

    menu.rebuild(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => false, "area_id" => "area.room" }
    }, {} as Dictionary));

    var vanished = AreaEntityMenuTest.itemOf(menu, "light.gone");
    Test.assertEqual(vanished.getLabel() as String, "Gone");
    Test.assert((vanished as WatchUi.ToggleMenuItem).isEnabled());

    Test.assert(!(AreaEntityMenuTest.itemOf(menu, "light.a") as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function aLightSublabelPicksUnavailableOverAGroupCount(logger as Test.Logger) as Boolean {
    var group = new LightRowModel("light.grp", "Group", false, false, 3);

    Test.assertEqual(AreaEntityMenu.toLightSubLabel(group) as String, "Group unavailable");
    return true;
}

(:test)
function anAvailableGroupShowsItsMemberCount(logger as Test.Logger) as Boolean {
    var one = new LightRowModel("light.one", "One", true, true, 1);
    var many = new LightRowModel("light.many", "Many", true, true, 4);

    Test.assertEqual(AreaEntityMenu.toLightSubLabel(one) as String, "Group • 1 Light");
    Test.assertEqual(AreaEntityMenu.toLightSubLabel(many) as String, "Group • 4 Lights");
    return true;
}

(:test)
function aSensorSublabelPicksUnavailableOverTheDisplayValue(logger as Test.Logger) as Boolean {
    // UNVERIFIED: Home Assistant formats an unavailable sensor as the word
    // unavailable followed by its unit.
    var dead = new SensorRowModel("sensor.t", "Temp", "unavailable °C", false);
    var live = new SensorRowModel("sensor.t", "Temp", "21.5 °C", true);

    Test.assertEqual(AreaEntityMenu.toSensorSubLabel(dead), "Unavailable");
    Test.assertEqual(AreaEntityMenu.toSensorSubLabel(live), "21.5 °C");
    return true;
}

(:test)
function aRowFallsBackToItsIdWhenHaNamesItNothing(logger as Test.Logger) as Boolean {
    Test.assertEqual(AreaEntityMenu.resolveLabel(null, "light.kitchen"), "light.kitchen");
    Test.assertEqual(AreaEntityMenu.resolveLabel("", "light.kitchen"), "light.kitchen");
    Test.assertEqual(AreaEntityMenu.resolveLabel("Kitchen Island", "light.kitchen"), "Kitchen Island");
    return true;
}

(:test)
function sensorRowsFollowLightRowsAndAreInert(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }, {
        "sensor.t" => { "state" => 21.5, "friendly_state" => "21.5 °C", "unit" => "°C",
            "device_class" => "temperature", "area_id" => "area.room" }
    }));

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.a");
    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getId() as String, "sensor.t");
    Test.assert(menu.getItem(2) == null);
    Test.assert(!(menu.getItem(1) instanceof WatchUi.ToggleMenuItem));
    return true;
}

(:test)
function anAreaWithNothingInItShowsOneInertRow(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(
        AreaEntityMenuTest.stateOf({} as Dictionary, {} as Dictionary));

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getLabel() as String,
        "No entities in the area");
    Test.assert(menu.getItem(1) == null);
    Test.assert(!(menu.getItem(0) instanceof WatchUi.ToggleMenuItem));
    return true;
}

(:test)
function aVanishedAreaMakesItsMenuObsolete(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }, {} as Dictionary));

    Test.assert(menu.isObsolete(new HaState()));
    return true;
}

(:test)
function aDomainArrivingAfterTheMenuOpenedAddsNoRow(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    haState.setZone(HaPayload.parseZone({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));
    haState.setAreas(HaPayload.parseAreas({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));
    haState.setFloors(HaPayload.parseFloors({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));
    haState.setLights(HaPayload.parseLights({
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.room" } }
    }));

    var menu = AreaEntityMenuTest.menuOf(haState);
    Test.assert(menu.getItem(1) == null);

    haState.setSensors(HaPayload.parseSensors({
        "sensors" => { "sensor.t" => { "state" => 21.5, "friendly_state" => "21.5 °C",
            "device_class" => "temperature", "area_id" => "area.room" } }
    }));
    menu.rebuild(haState);

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.a");
    Test.assert(menu.getItem(1) == null);
    return true;
}

(:test)
function theEmptyRowOutlivesTheEntitiesArriving(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    haState.setZone(HaPayload.parseZone({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));
    haState.setAreas(HaPayload.parseAreas({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));
    haState.setFloors(HaPayload.parseFloors({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));

    var menu = AreaEntityMenuTest.menuOf(haState);
    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getLabel() as String,
        "No entities in the area");

    haState.setLights(HaPayload.parseLights({
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.room" } }
    }));
    menu.rebuild(haState);

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getLabel() as String,
        "No entities in the area");
    Test.assert(menu.getItem(1) == null);
    return true;
}
