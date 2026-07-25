import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Exercises the light-menu row seams directly on the session's state map, so no
// networking is involved.

(:test)
module LightMenuTest {

    function sessionWith(states as Dictionary<String, Boolean>) as LightSession {
        var state = LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new LightSession(new HaClient(), state);
    }

    function sessionWithNames(states as Dictionary<String, Boolean>,
                             names as Dictionary<String, String>) as LightSession {
        var state = LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "names" => names
        });
        return new LightSession(new HaClient(), state);
    }

    function sessionWithGroups(states as Dictionary<String, Boolean>,
                              groups as Dictionary<String, Number>) as LightSession {
        var state = LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "groups" => groups
        });
        return new LightSession(new HaClient(), state);
    }

    function snapshotOf(states as Dictionary<String, Boolean>) as LightState {
        return LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
    }
}

(:test)
function rowSwitchReflectsIsOnWhenBuilt(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWith({ "light.on" => true, "light.off" => false });

    Test.assert(LightMenu.makeItem(session, "light.on").isEnabled());
    Test.assert(!LightMenu.makeItem(session, "light.off").isEnabled());
    return true;
}

(:test)
function reconciledRowReflectsConvergedTruth(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWith({ "light.x" => true });
    var menu = new LightMenu(session, "Room", ["light.x"]);

    session.reconcile(LightMenuTest.snapshotOf({ "light.x" => false }));
    menu.refresh();

    Test.assert(!(menu.getItem(menu.findItemById("light.x")) as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function toggleShowsNoTransientSubLabel(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 3 });
    var menu = new LightMenu(session, "Room", ["light.grp"]);
    var item = menu.getItem(menu.findItemById("light.grp")) as WatchUi.ToggleMenuItem;

    new LightMenuDelegate(menu, session).onSelect(item);

    Test.assertEqual(item.getSubLabel() as String, "3 lights");
    return true;
}

(:test)
function groupRowShowsMemberCount(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 4 });

    Test.assertEqual(LightMenu.idleSubLabel(session, "light.grp") as String, "4 lights");
    return true;
}

(:test)
function singleMemberGroupIsSingular(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 1 });

    Test.assertEqual(LightMenu.idleSubLabel(session, "light.grp") as String, "1 light");
    return true;
}

(:test)
function zeroMemberGroupShowsZero(logger as Test.Logger) as Boolean {
    // A group that expands to nothing reads "0 lights" honestly until empty
    // groups are filtered upstream; the plural branch covers zero.
    var session = LightMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 0 });

    Test.assertEqual(LightMenu.idleSubLabel(session, "light.grp") as String, "0 lights");
    return true;
}

(:test)
function plainLightHasNoSubLabel(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithGroups(
        { "light.plain" => true }, {} as Dictionary<String, Number>);

    Test.assert(LightMenu.idleSubLabel(session, "light.plain") == null);
    return true;
}

(:test)
function rowLabelUsesHaName(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithNames(
        { "light.kitchen" => true },
        { "light.kitchen" => "Kitchen Island" });

    Test.assertEqual(LightMenu.makeItem(session, "light.kitchen").getLabel() as String, "Kitchen Island");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameMissing(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithNames(
        { "light.kitchen" => true },
        {} as Dictionary<String, String>);

    Test.assertEqual(LightMenu.makeItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}

(:test)
function rowLabelFallsBackToIdWhenNameEmpty(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWithNames(
        { "light.kitchen" => true },
        { "light.kitchen" => "" });

    Test.assertEqual(LightMenu.makeItem(session, "light.kitchen").getLabel() as String, "light.kitchen");
    return true;
}
