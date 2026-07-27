import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Exercises the entity-menu row seams directly on the session's state map, so no
// networking is involved.
//
// Row counts are asserted by probing one index past the last expected row:
// Menu2 exposes no count accessor, and getItem is declared `MenuItem or Null`
// with an out-of-range index as its only source of that null.

(:test)
module EntityMenuTest {

    function sessionWith(states as Dictionary<String, Boolean>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new HomeSession(new HaClient(), state);
    }

    function sessionWithNames(states as Dictionary<String, Boolean>,
                             names as Dictionary<String, String>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "names" => names
        });
        return new HomeSession(new HaClient(), state);
    }

    function sessionWithGroups(states as Dictionary<String, Boolean>,
                              groups as Dictionary<String, Number>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "groups" => groups
        });
        return new HomeSession(new HaClient(), state);
    }

    function sessionWithAvailability(states as Dictionary<String, Boolean>,
                                    groups as Dictionary<String, Number>,
                                    available as Dictionary<String, Boolean>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "groups" => groups,
            "available" => available
        });
        return new HomeSession(new HaClient(), state);
    }

    function stateOf(states as Dictionary<String, Boolean>) as HomeState {
        return HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
    }

    function stateWithSensors(states as Dictionary<String, Boolean>, sensors as Array<String>,
                             readings as Dictionary<String, String>,
                             available as Dictionary<String, Boolean>) as HomeState {
        return HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "sensors" => { "Room" => sensors },
            "states" => states,
            "readings" => readings,
            "available" => available
        });
    }

    function sessionWithSensors(states as Dictionary<String, Boolean>, sensors as Array<String>,
                               readings as Dictionary<String, String>) as HomeSession {
        return new HomeSession(new HaClient(), stateWithSensors(
            states, sensors, readings, {} as Dictionary<String, Boolean>));
    }

    function sessionWithSensorAvailability(sensors as Array<String>,
                                          readings as Dictionary<String, String>,
                                          available as Dictionary<String, Boolean>) as HomeSession {
        return new HomeSession(new HaClient(), stateWithSensors(
            {} as Dictionary<String, Boolean>, sensors, readings, available));
    }
}

(:test)
function rowSwitchReflectsIsOnWhenBuilt(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWith({ "light.on" => true, "light.off" => false });

    Test.assert(EntityMenu.buildItem(session, "light.on").isEnabled());
    Test.assert(!EntityMenu.buildItem(session, "light.off").isEnabled());
    return true;
}

(:test)
function appliedStateRowReflectsConvergedTruth(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWith({ "light.x" => true });
    var menu = new EntityMenu(session, "Room", ["light.x"], [] as Array<String>);

    session.applyState(EntityMenuTest.stateOf({ "light.x" => false }));
    menu.redraw();

    Test.assert(!(menu.getItem(menu.findItemById("light.x")) as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function toggleShowsNoTransientSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 3 });
    var menu = new EntityMenu(session, "Room", ["light.grp"], [] as Array<String>);
    var item = menu.getItem(menu.findItemById("light.grp")) as WatchUi.ToggleMenuItem;

    new EntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(item.getSubLabel() as String, "3 lights");
    return true;
}

(:test)
function groupRowShowsMemberCount(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 4 });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.grp") as String, "4 lights");
    return true;
}

(:test)
function singleMemberGroupIsSingular(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 1 });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.grp") as String, "1 light");
    return true;
}

(:test)
function plainLightHasNoSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithGroups(
        { "light.plain" => true }, {} as Dictionary<String, Number>);

    Test.assert(EntityMenu.buildSubLabel(session, "light.plain") == null);
    return true;
}

(:test)
function unavailablePlainRowShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithAvailability(
        { "light.plain" => false }, {} as Dictionary<String, Number>,
        { "light.plain" => false });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.plain") as String, "Unavailable");
    return true;
}

(:test)
function unavailableGroupRowShowsGroupUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithAvailability(
        { "light.grp" => false }, { "light.grp" => 3 },
        { "light.grp" => false });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.grp") as String, "Group unavailable");
    return true;
}

(:test)
function rowLabelUsesHaName(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithNames(
        { "light.kitchen" => true },
        { "light.kitchen" => "Kitchen Island" });

    Test.assertEqual(EntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "Kitchen Island");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameMissing(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithNames(
        { "light.kitchen" => true },
        {} as Dictionary<String, String>);

    Test.assertEqual(EntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameEmpty(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithNames(
        { "light.kitchen" => true },
        { "light.kitchen" => "" });

    Test.assertEqual(EntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function sensorRowsFollowLightRowsInSensorOrder(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithSensors(
        { "light.x" => true },
        ["sensor.temperature", "sensor.humidity", "sensor.illuminance"],
        { "sensor.temperature" => "21.5 C", "sensor.humidity" => "43 %",
          "sensor.illuminance" => "120 lx" });
    var menu = new EntityMenu(session, "Room", ["light.x"], session.listSensorsInArea("Room"));

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.x");
    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getId() as String, "sensor.temperature");
    Test.assertEqual((menu.getItem(2) as WatchUi.MenuItem).getId() as String, "sensor.humidity");
    Test.assertEqual((menu.getItem(3) as WatchUi.MenuItem).getId() as String, "sensor.illuminance");
    Test.assert(menu.getItem(4) == null);
    return true;
}

(:test)
function areaWithNoEntitiesShowsOneInertRow(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWith({} as Dictionary<String, Boolean>);
    var menu = new EntityMenu(session, "Room", [] as Array<String>, [] as Array<String>);
    var item = menu.getItem(0) as WatchUi.MenuItem;

    Test.assertEqual(item.getLabel() as String, "No entities found");
    Test.assert(menu.getItem(1) == null);

    // Must not reach the toggle path, which would cast the :none id to a String.
    new EntityMenuDelegate(menu, session).onSelect(item);
    return true;
}

(:test)
function sensorRowShowsReadingAsSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithSensors(
        {} as Dictionary<String, Boolean>, ["sensor.temperature"],
        { "sensor.temperature" => "21.5 C" });
    var item = EntityMenu.buildSensorItem(session, "sensor.temperature");

    Test.assertEqual(item.getSubLabel() as String, "21.5 C");
    return true;
}

(:test)
function unavailableSensorRowShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithSensorAvailability(
        ["sensor.temperature"], { "sensor.temperature" => "unavailable" },
        { "sensor.temperature" => false });

    Test.assertEqual(EntityMenu.buildReading(session, "sensor.temperature"), "Unavailable");
    return true;
}

// A sensor HA reports as `unknown` gets no test of its own: the template folds
// unknown into the availability flag server-side, so by the time a reading
// reaches this seam it is indistinguishable from a dead one, and a test would
// only re-assert the case above.

(:test)
function sensorRowWithoutReadingShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithSensors(
        {} as Dictionary<String, Boolean>, ["sensor.temperature"],
        {} as Dictionary<String, String>);

    Test.assertEqual(EntityMenu.buildReading(session, "sensor.temperature"), "Unavailable");
    return true;
}

(:test)
function selectingSensorRowLeavesEverythingAlone(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithSensors(
        {} as Dictionary<String, Boolean>, ["sensor.temperature"],
        { "sensor.temperature" => "21.5 C" });
    var menu = new EntityMenu(session, "Room", [] as Array<String>,
                              session.listSensorsInArea("Room"));
    var item = menu.getItem(menu.findItemById("sensor.temperature")) as WatchUi.MenuItem;

    new EntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(item.getSubLabel() as String, "21.5 C");
    // A service call goes through toggleState, which would start tracking the id.
    Test.assert(!session.isTracked("sensor.temperature"));
    return true;
}

(:test)
function appliedStateRowsShowNewReadingsInPlace(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithSensors(
        { "light.x" => true }, ["sensor.temperature", "sensor.humidity"],
        { "sensor.temperature" => "21.5 C", "sensor.humidity" => "43 %" });
    var menu = new EntityMenu(session, "Room", ["light.x"], session.listSensorsInArea("Room"));

    session.applyState(EntityMenuTest.stateWithSensors(
        { "light.x" => false }, ["sensor.temperature", "sensor.humidity"],
        { "sensor.temperature" => "22.1 C", "sensor.humidity" => "44 %" },
        {} as Dictionary<String, Boolean>));
    menu.redraw();

    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getSubLabel() as String, "22.1 C");
    Test.assertEqual((menu.getItem(2) as WatchUi.MenuItem).getSubLabel() as String, "44 %");
    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.x");
    Test.assert(!(menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
    Test.assert(menu.getItem(3) == null);
    return true;
}
