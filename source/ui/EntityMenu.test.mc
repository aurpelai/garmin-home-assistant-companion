import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Exercises the entity-menu row seams directly on the session's state map, so no
// networking is involved.

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
    var menu = new EntityMenu(session, "Room", ["light.x"]);

    session.applyState(EntityMenuTest.stateOf({ "light.x" => false }));
    menu.redraw();

    Test.assert(!(menu.getItem(menu.findItemById("light.x")) as WatchUi.ToggleMenuItem).isEnabled());
    return true;
}

(:test)
function toggleShowsNoTransientSubLabel(logger as Test.Logger) as Boolean {
    var session = EntityMenuTest.sessionWithGroups(
        { "light.grp" => true }, { "light.grp" => 3 });
    var menu = new EntityMenu(session, "Room", ["light.grp"]);
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
