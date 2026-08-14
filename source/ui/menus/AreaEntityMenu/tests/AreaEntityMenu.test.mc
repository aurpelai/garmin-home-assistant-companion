import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Drives the push seam through the platform menu's own accessors: a model in,
// item labels and states out.
//
// Row counts are asserted by probing one index past the last expected row:
// Menu2 exposes no count accessor, and getItem is declared `MenuItem or Null`
// with an out-of-range index as its only source of that null.

(:test)
module AreaEntityMenuTest {

    function stateOf(lights as Dictionary, sensors as Dictionary) as HaState {
        var haState = new HaState();

        haState.setStructure(HaPayload.parseStructure({
            "areas" => { "area.room" => { "name" => "Room" } }
        }));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
        haState.setSensors(HaPayload.parseSensors({ "sensors" => sensors }));

        return haState;
    }

    function menuOf(haState as HaState) as AreaEntityMenu {
        var model = buildAreaEntityMenuModel(haState, "area.room") as AreaEntityMenuModel;
        return new AreaEntityMenu(new Coordinator(new HaClient()), "area.room", model);
    }

    function itemOf(menu as AreaEntityMenu, rowId as String) as WatchUi.MenuItem {
        return menu.getItem(menu.findItemById(rowId)) as WatchUi.MenuItem;
    }
}

(:test)
function aPushChangesTheItemSetInNeitherDirection(logger as Test.Logger) as Boolean {
    // The freeze is what makes a row impossible to move or lose under the
    // user's finger, so a model that both drops an entry and gains one leaves
    // every item exactly where it was — the gained entity is not added either.
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
    // Driven by model entries, so an entity with no entry is never visited and
    // its row keeps what it last showed rather than being blanked or removed.
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
function aPushMovesTheSwitchToTheModelsState(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }, {} as Dictionary));

    Test.assert((AreaEntityMenuTest.itemOf(menu, "light.a") as WatchUi.ToggleMenuItem).isEnabled());

    menu.rebuild(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => false, "area_id" => "area.room" }
    }, {} as Dictionary));

    Test.assert(!(AreaEntityMenuTest.itemOf(menu, "light.a") as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function aLightSublabelPicksUnavailableOverAGroupCount(logger as Test.Logger) as Boolean {
    // An unavailable group would otherwise read as a member count, hiding that
    // nothing in it can be reached.
    var group = new LightRowModel("light.grp", "light.grp", "Group", false, false, 3, false);

    Test.assertEqual(AreaEntityMenu.lightSubLabel(group) as String, "Group unavailable");
    return true;
}

(:test)
function anAvailableGroupShowsItsMemberCount(logger as Test.Logger) as Boolean {
    var one = new LightRowModel("light.one", "light.one", "One", true, true, 1, false);
    var many = new LightRowModel("light.many", "light.many", "Many", true, true, 4, false);

    Test.assertEqual(AreaEntityMenu.lightSubLabel(one) as String, "Group • 1 Light");
    Test.assertEqual(AreaEntityMenu.lightSubLabel(many) as String, "Group • 4 Lights");
    return true;
}

(:test)
function anAvailablePlainLightShowsNoSublabel(logger as Test.Logger) as Boolean {
    var plain = new LightRowModel("light.plain", "light.plain", "Plain", true, true, null, false);

    Test.assert(AreaEntityMenu.lightSubLabel(plain) == null);
    return true;
}

(:test)
function anUnavailablePlainLightSaysSoRatherThanNothing(logger as Test.Logger) as Boolean {
    var plain = new LightRowModel("light.plain", "light.plain", "Plain", false, false, null, false);

    Test.assertEqual(AreaEntityMenu.lightSubLabel(plain) as String, "Unavailable");
    return true;
}

(:test)
function aSensorSublabelPicksUnavailableOverTheDisplayValue(logger as Test.Logger) as Boolean {
    // Home Assistant formats whatever the state is, so an unavailable sensor
    // would otherwise render as the word unavailable followed by a unit.
    var dead = new SensorRowModel("sensor.t", "Temp", "unavailable °C", false);
    var live = new SensorRowModel("sensor.t", "Temp", "21.5 °C", true);

    Test.assertEqual(AreaEntityMenu.sensorSubLabel(dead), "Unavailable");
    Test.assertEqual(AreaEntityMenu.sensorSubLabel(live), "21.5 °C");
    return true;
}

(:test)
function aSensorWithNoDisplayValueSaysUnavailable(logger as Test.Logger) as Boolean {
    var blank = new SensorRowModel("sensor.t", "Temp", null, true);

    Test.assertEqual(AreaEntityMenu.sensorSubLabel(blank), "Unavailable");
    return true;
}

(:test)
function aRowFallsBackToItsIdWhenHaNamesItNothing(logger as Test.Logger) as Boolean {
    Test.assertEqual(AreaEntityMenu.labelOf(null, "light.kitchen"), "light.kitchen");
    Test.assertEqual(AreaEntityMenu.labelOf("", "light.kitchen"), "light.kitchen");
    Test.assertEqual(AreaEntityMenu.labelOf("Kitchen Island", "light.kitchen"), "Kitchen Island");
    return true;
}

(:test)
function rawNonAsciiNamesAndReadingsSurviveTheSeam(logger as Test.Logger) as Boolean {
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room", "name" => "Küche Décor" }
    }, {
        "sensor.t" => { "state" => 21.5, "display_state" => "21,5 °C", "unit" => "°C",
            "device_class" => "temperature", "area_id" => "area.room", "name" => "Temperatur" }
    }));

    Test.assertEqual(AreaEntityMenuTest.itemOf(menu, "light.a").getLabel() as String, "Küche Décor");
    Test.assertEqual(AreaEntityMenuTest.itemOf(menu, "sensor.t").getSubLabel() as String, "21,5 °C");
    return true;
}

(:test)
function sensorRowsFollowLightRowsAndAreInert(logger as Test.Logger) as Boolean {
    // Being a plain MenuItem is what makes a sensor row inert, so the ordering
    // and the row type are one decision rather than two.
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }, {
        "sensor.t" => { "state" => 21.5, "display_state" => "21.5 °C", "unit" => "°C",
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
function aVanishedAreaReportsItsSubjectGoneRatherThanPushing(logger as Test.Logger) as Boolean {
    // What tells the coordinator to navigate: the view neither decides the
    // destination nor renders a screen whose subject no longer exists.
    var menu = AreaEntityMenuTest.menuOf(AreaEntityMenuTest.stateOf({
        "light.a" => { "state" => true, "area_id" => "area.room" }
    }, {} as Dictionary));

    Test.assert(menu.rebuild(new HaState()) == false);
    return true;
}

(:test)
function aDomainArrivingAfterTheMenuOpenedAddsNoRow(logger as Test.Logger) as Boolean {
    // A refresh fetches lights and sensors as separate requests, so a menu
    // opened between the two shows only what had landed. The accepted cost of
    // the freeze: reopening the menu is what reveals the rest.
    var haState = new HaState();
    haState.setStructure(HaPayload.parseStructure({
        "areas" => { "area.room" => { "name" => "Room" } }
    }));
    haState.setLights(HaPayload.parseLights({
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.room" } }
    }));

    var menu = AreaEntityMenuTest.menuOf(haState);
    Test.assert(menu.getItem(1) == null);

    haState.setSensors(HaPayload.parseSensors({
        "sensors" => { "sensor.t" => { "state" => 21.5, "display_state" => "21.5 °C",
            "device_class" => "temperature", "area_id" => "area.room" } }
    }));
    menu.rebuild(haState);

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.a");
    Test.assert(menu.getItem(1) == null);
    return true;
}

(:test)
function theEmptyRowOutlivesTheEntitiesArriving(logger as Test.Logger) as Boolean {
    // Frozen like every other row rather than special-cased: removing it would
    // be the item set changing under an open menu, which is the one thing the
    // freeze forbids.
    var haState = new HaState();
    haState.setStructure(HaPayload.parseStructure({
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
