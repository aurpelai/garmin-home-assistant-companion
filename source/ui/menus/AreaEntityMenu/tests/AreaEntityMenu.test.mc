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
module AreaEntityMenuTest {

    function stateOf(payload as Dictionary) as HomeState {
        return HomeState.fromTemplateData(payload);
    }

    function sessionOf(payload as Dictionary) as HomeSession {
        return new HomeSession(new HaClient(), stateOf(payload));
    }
}

(:test)
function rowSwitchReflectsIsOnWhenBuilt(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.on" => { "state" => true }, "light.off" => { "state" => false } }
    });

    Test.assert(AreaEntityMenu.buildItem(session, "light.on").isEnabled());
    Test.assert(!AreaEntityMenu.buildItem(session, "light.off").isEnabled());
    return true;
}

(:test)
function appliedStateRowReflectsConvergedTruth(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({ "lights" => { "light.x" => { "state" => true } } });
    var menu = new AreaEntityMenu(session, "Room", ["light.x"], [] as Array<String>);

    session.applyState(AreaEntityMenuTest.stateOf({ "lights" => { "light.x" => { "state" => false } } }));
    menu.draw();

    Test.assert(!(menu.getItem(menu.findItemById("light.x")) as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function toggleShowsNoTransientSubLabel(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.grp" => { "state" => true, "memberCount" => 3 } }
    });
    var menu = new AreaEntityMenu(session, "Room", ["light.grp"], [] as Array<String>);
    var item = menu.getItem(menu.findItemById("light.grp")) as WatchUi.ToggleMenuItem;

    new AreaEntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(item.getSubLabel() as String, "Group • 3 Lights");
    return true;
}

(:test)
function groupRowShowsMemberCount(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.grp" => { "state" => true, "memberCount" => 4 } }
    });

    Test.assertEqual(AreaEntityMenu.buildSubLabel(session, "light.grp") as String, "Group • 4 Lights");
    return true;
}

(:test)
function singleMemberGroupIsSingular(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.grp" => { "state" => true, "memberCount" => 1 } }
    });

    Test.assertEqual(AreaEntityMenu.buildSubLabel(session, "light.grp") as String, "Group • 1 Light");
    return true;
}

(:test)
function plainLightHasNoSubLabel(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.plain" => { "state" => true } }
    });

    Test.assert(AreaEntityMenu.buildSubLabel(session, "light.plain") == null);
    return true;
}

(:test)
function unavailablePlainRowShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.plain" => { "state" => false, "available" => false } }
    });

    Test.assertEqual(AreaEntityMenu.buildSubLabel(session, "light.plain") as String, "Unavailable");
    return true;
}

(:test)
function unavailableGroupRowShowsGroupUnavailable(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.grp" => { "state" => false, "memberCount" => 3, "available" => false } }
    });

    Test.assertEqual(AreaEntityMenu.buildSubLabel(session, "light.grp") as String, "Group unavailable");
    return true;
}

(:test)
function rowLabelUsesHaName(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.kitchen" => { "state" => true, "name" => "Kitchen Island" } }
    });

    Test.assertEqual(AreaEntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "Kitchen Island");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameMissing(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.kitchen" => { "state" => true } }
    });

    Test.assertEqual(AreaEntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameEmpty(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "lights" => { "light.kitchen" => { "state" => true, "name" => "" } }
    });

    Test.assertEqual(AreaEntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function sensorRowsFollowLightRowsInSensorOrder(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room", "lights" => ["light.x"],
            "sensors" => ["sensor.temperature", "sensor.humidity", "sensor.illuminance"] } },
        "lights" => { "light.x" => { "state" => true } },
        "sensors" => {
            "sensor.temperature" => { "state" => 21.5, "display_state" => "21.5 C", "unit" => "C" },
            "sensor.humidity" => { "state" => 43, "display_state" => "43 %", "unit" => "%" },
            "sensor.illuminance" => { "state" => 120, "display_state" => "120 lx", "unit" => "lx" }
        }
    });
    var menu = new AreaEntityMenu(session, "Room", ["light.x"], session.listSensorsInArea("area.room"));

    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.x");
    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getId() as String, "sensor.temperature");
    Test.assertEqual((menu.getItem(2) as WatchUi.MenuItem).getId() as String, "sensor.humidity");
    Test.assertEqual((menu.getItem(3) as WatchUi.MenuItem).getId() as String, "sensor.illuminance");
    Test.assert(menu.getItem(4) == null);
    return true;
}

(:test)
function areaWithNoEntitiesShowsOneInertRow(logger as Test.Logger) as Boolean {
    var client = new FakeHaClient();
    var session = new HomeSession(client, AreaEntityMenuTest.stateOf({} as Dictionary));
    var menu = new AreaEntityMenu(session, "Room", [] as Array<String>, [] as Array<String>);
    var item = menu.getItem(0) as WatchUi.MenuItem;

    Test.assertEqual(item.getLabel() as String, "No entities found");
    Test.assert(menu.getItem(1) == null);

    new AreaEntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(client.toggleCount, 0);
    return true;
}

(:test)
function sensorRowShowsReadingAsSubLabel(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "sensors" => { "sensor.temperature" => { "state" => 21.5, "display_state" => "21.5 C", "unit" => "C" } }
    });
    var item = AreaEntityMenu.buildSensorItem(session, "sensor.temperature");

    Test.assertEqual(item.getSubLabel() as String, "21.5 C");
    return true;
}

(:test)
function unavailableSensorRowShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "sensors" => { "sensor.temperature" => { "state" => 22, "display_state" => "22 °C", "unit" => "°C",
            "available" => false } }
    });

    Test.assertEqual(AreaEntityMenu.buildReading(session, "sensor.temperature"), "Unavailable");
    return true;
}

// A sensor HA reports as `unknown` gets no test of its own: the template folds
// unknown into the availability flag server-side, so by the time a reading
// reaches this seam it is indistinguishable from a dead one, and a test would
// only re-assert the case above.

(:test)
function sensorRowWithoutReadingShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "sensors" => {} as Dictionary
    });

    Test.assertEqual(AreaEntityMenu.buildReading(session, "sensor.temperature"), "Unavailable");
    return true;
}

(:test)
function selectingSensorRowLeavesEverythingAlone(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room", "sensors" => ["sensor.temperature"] } },
        "sensors" => { "sensor.temperature" => { "state" => 21.5, "display_state" => "21.5 C", "unit" => "C" } }
    });
    var menu = new AreaEntityMenu(session, "Room", [] as Array<String>,
                              session.listSensorsInArea("area.room"));
    var item = menu.getItem(menu.findItemById("sensor.temperature")) as WatchUi.MenuItem;

    new AreaEntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(item.getSubLabel() as String, "21.5 C");
    // A service call goes through toggleState, which would start tracking the id.
    Test.assert(!session.isTracked("sensor.temperature"));
    return true;
}

(:test)
function appliedStateRowsShowNewReadingsInPlace(logger as Test.Logger) as Boolean {
    var session = AreaEntityMenuTest.sessionOf({
        "areas" => { "area.room" => { "name" => "Room", "lights" => ["light.x"],
            "sensors" => ["sensor.temperature", "sensor.humidity"] } },
        "lights" => { "light.x" => { "state" => true } },
        "sensors" => {
            "sensor.temperature" => { "state" => 21.5, "display_state" => "21.5 C", "unit" => "C" },
            "sensor.humidity" => { "state" => 43, "display_state" => "43 %", "unit" => "%" }
        }
    });
    var menu = new AreaEntityMenu(session, "Room", ["light.x"], session.listSensorsInArea("area.room"));

    session.applyState(AreaEntityMenuTest.stateOf({
        "areas" => { "area.room" => { "name" => "Room", "lights" => ["light.x"],
            "sensors" => ["sensor.temperature", "sensor.humidity"] } },
        "lights" => { "light.x" => { "state" => false } },
        "sensors" => {
            "sensor.temperature" => { "state" => 22.1, "display_state" => "22.1 C", "unit" => "C" },
            "sensor.humidity" => { "state" => 44, "display_state" => "44 %", "unit" => "%" }
        }
    }));
    menu.draw();

    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getSubLabel() as String, "22.1 C");
    Test.assertEqual((menu.getItem(2) as WatchUi.MenuItem).getSubLabel() as String, "44 %");
    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.x");
    Test.assert(!(menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
    Test.assert(menu.getItem(3) == null);
    return true;
}
