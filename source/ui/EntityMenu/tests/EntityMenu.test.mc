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

    function stateOf(payload as Dictionary) as HomeState {
        return HomeState.fromTemplateData(payload);
    }

    function sessionOf(payload as Dictionary) as HomeSession {
        return new HomeSession(new HaClient(), stateOf(payload));
    }
}

(:test)
function rowSwitchReflectsIsOnWhenBuilt(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.on" => true, "light.off" => false }
    });

    Test.assert(EntityMenu.buildItem(session, "light.on").isEnabled());
    Test.assert(!EntityMenu.buildItem(session, "light.off").isEnabled());
    return true;
}

(:test)
function appliedStateRowReflectsConvergedTruth(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({ "states" => { "light.x" => true } });
    var menu = new EntityMenu(session, "Room", ["light.x"], [] as Array<String>);

    session.applyState(EntityMenuTest.stateOf({ "states" => { "light.x" => false } }));
    menu.redraw();

    Test.assert(!(menu.getItem(menu.findItemById("light.x")) as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function toggleShowsNoTransientSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.grp" => true },
        "groups" => { "light.grp" => 3 }
    });
    var menu = new EntityMenu(session, "Room", ["light.grp"], [] as Array<String>);
    var item = menu.getItem(menu.findItemById("light.grp")) as WatchUi.ToggleMenuItem;

    new EntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(item.getSubLabel() as String, "Group • 3 Lights");
    return true;
}

(:test)
function groupRowShowsMemberCount(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.grp" => true },
        "groups" => { "light.grp" => 4 }
    });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.grp") as String, "Group • 4 Lights");
    return true;
}

(:test)
function singleMemberGroupIsSingular(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.grp" => true },
        "groups" => { "light.grp" => 1 }
    });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.grp") as String, "Group • 1 Light");
    return true;
}

(:test)
function plainLightHasNoSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.plain" => true },
        "groups" => {} as Dictionary<String, Number>
    });

    Test.assert(EntityMenu.buildSubLabel(session, "light.plain") == null);
    return true;
}

(:test)
function unavailablePlainRowShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.plain" => false },
        "available" => { "light.plain" => false }
    });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.plain") as String, "Unavailable");
    return true;
}

(:test)
function unavailableGroupRowShowsGroupUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.grp" => false },
        "groups" => { "light.grp" => 3 },
        "available" => { "light.grp" => false }
    });

    Test.assertEqual(EntityMenu.buildSubLabel(session, "light.grp") as String, "Group unavailable");
    return true;
}

(:test)
function rowLabelUsesHaName(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.kitchen" => true },
        "names" => { "light.kitchen" => "Kitchen Island" }
    });

    Test.assertEqual(EntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "Kitchen Island");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameMissing(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.kitchen" => true },
        "names" => {} as Dictionary<String, String>
    });

    Test.assertEqual(EntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameEmpty(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "states" => { "light.kitchen" => true },
        "names" => { "light.kitchen" => "" }
    });

    Test.assertEqual(EntityMenu.buildItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function sensorRowsFollowLightRowsInSensorOrder(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "areas" => { "Room" => ["light.x"] },
        "sensors" => { "Room" => ["sensor.temperature", "sensor.humidity", "sensor.illuminance"] },
        "states" => { "light.x" => true },
        "readings" => {
            "sensor.temperature" => { "value" => 21.5, "display" => "21.5 C", "unit" => "C" },
            "sensor.humidity" => { "value" => 43, "display" => "43 %", "unit" => "%" },
            "sensor.illuminance" => { "value" => 120, "display" => "120 lx", "unit" => "lx" }
        }
    });
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
    var client = new FakeHaClient();
    var session = new HomeSession(client, EntityMenuTest.stateOf({} as Dictionary));
    var menu = new EntityMenu(session, "Room", [] as Array<String>, [] as Array<String>);
    var item = menu.getItem(0) as WatchUi.MenuItem;

    Test.assertEqual(item.getLabel() as String, "No entities found");
    Test.assert(menu.getItem(1) == null);

    new EntityMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(client.toggleCount, 0);
    return true;
}

(:test)
function sensorRowShowsReadingAsSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "readings" => { "sensor.temperature" => { "value" => 21.5, "display" => "21.5 C", "unit" => "C" } }
    });
    var item = EntityMenu.buildSensorItem(session, "sensor.temperature");

    Test.assertEqual(item.getSubLabel() as String, "21.5 C");
    return true;
}

(:test)
function unavailableSensorRowShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "readings" => { "sensor.temperature" => { "value" => 22, "display" => "22 °C", "unit" => "°C" } },
        "available" => { "sensor.temperature" => false }
    });

    Test.assertEqual(EntityMenu.buildReading(session, "sensor.temperature"), "Unavailable");
    return true;
}

// A sensor HA reports as `unknown` gets no test of its own: the template folds
// unknown into the availability flag server-side, so by the time a reading
// reaches this seam it is indistinguishable from a dead one, and a test would
// only re-assert the case above.

(:test)
function sensorRowWithoutReadingShowsUnavailable(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "readings" => {} as Dictionary<String, Dictionary>
    });

    Test.assertEqual(EntityMenu.buildReading(session, "sensor.temperature"), "Unavailable");
    return true;
}

(:test)
function selectingSensorRowLeavesEverythingAlone(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionOf({
        "areas" => { "Room" => [] as Array<String> },
        "sensors" => { "Room" => ["sensor.temperature"] },
        "readings" => { "sensor.temperature" => { "value" => 21.5, "display" => "21.5 C", "unit" => "C" } }
    });
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
    var session = EntityMenuTest.sessionOf({
        "areas" => { "Room" => ["light.x"] },
        "sensors" => { "Room" => ["sensor.temperature", "sensor.humidity"] },
        "states" => { "light.x" => true },
        "readings" => {
            "sensor.temperature" => { "value" => 21.5, "display" => "21.5 C", "unit" => "C" },
            "sensor.humidity" => { "value" => 43, "display" => "43 %", "unit" => "%" }
        }
    });
    var menu = new EntityMenu(session, "Room", ["light.x"], session.listSensorsInArea("Room"));

    session.applyState(EntityMenuTest.stateOf({
        "areas" => { "Room" => ["light.x"] },
        "sensors" => { "Room" => ["sensor.temperature", "sensor.humidity"] },
        "states" => { "light.x" => false },
        "readings" => {
            "sensor.temperature" => { "value" => 22.1, "display" => "22.1 C", "unit" => "C" },
            "sensor.humidity" => { "value" => 44, "display" => "44 %", "unit" => "%" }
        }
    }));
    menu.redraw();

    Test.assertEqual((menu.getItem(1) as WatchUi.MenuItem).getSubLabel() as String, "22.1 C");
    Test.assertEqual((menu.getItem(2) as WatchUi.MenuItem).getSubLabel() as String, "44 %");
    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getId() as String, "light.x");
    Test.assert(!(menu.getItem(0) as WatchUi.ToggleMenuItem).isEnabled());
    Test.assert(menu.getItem(3) == null);
    return true;
}
