import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Exercises the light-menu row seams directly on the session's state map, so no
// networking is involved.

module LightMenuTest {

    function sessionWith(states as Dictionary<String, Boolean>) as LightSession {
        var state = LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new LightSession(new HaClient(), state);
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
function switchStaysOnAfterSuccessfulToggle(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWith({ "light.x" => true });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, session, "light.x", null).onComplete();

    Test.assert(item.isEnabled());
    Test.assert(item.getSubLabel() == null);
    return true;
}

(:test)
function switchFlipsBackAfterFailedToggle(logger as Test.Logger) as Boolean {
    // Switch still shows on (auto-flipped on tap); session reverted to off.
    var session = LightMenuTest.sessionWith({ "light.x" => false });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, session, "light.x", null).onComplete();

    Test.assert(!item.isEnabled());
    Test.assert(item.getSubLabel() == null);
    return true;
}

(:test)
function idleSubLabelRestoredAfterToggle(logger as Test.Logger) as Boolean {
    var session = LightMenuTest.sessionWith({ "light.x" => true });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, session, "light.x", "3 lights").onComplete();

    Test.assertEqual(item.getSubLabel() as String, "3 lights");
    return true;
}

(:test)
function stripDomainRemovesDomainPrefix(logger as Test.Logger) as Boolean {
    Test.assertEqual(LightMenu.stripDomain("light.kitchen_ceiling"), "kitchen_ceiling");
    return true;
}

(:test)
function stripDomainKeepsUnprefixedId(logger as Test.Logger) as Boolean {
    Test.assertEqual(LightMenu.stripDomain("kitchen_ceiling"), "kitchen_ceiling");
    return true;
}

(:test)
function stripDomainHandlesTrailingDot(logger as Test.Logger) as Boolean {
    Test.assertEqual(LightMenu.stripDomain("light."), "");
    return true;
}

(:test)
function toTitleCaseCapitalizesSingleWord(logger as Test.Logger) as Boolean {
    Test.assertEqual(LightMenu.toTitleCase("kitchen"), "Kitchen");
    return true;
}

(:test)
function toTitleCaseCapitalizesEachWord(logger as Test.Logger) as Boolean {
    Test.assertEqual(LightMenu.toTitleCase("kitchen_ceiling"), "Kitchen Ceiling");
    return true;
}

(:test)
function toTitleCaseHandlesEdgeSeparators(logger as Test.Logger) as Boolean {
    // Leading, trailing, and doubled separators become spaces; empty tokens do
    // not get a stray capital.
    Test.assertEqual(LightMenu.toTitleCase("_kitchen__ceiling_"), " Kitchen  Ceiling ");
    return true;
}

(:test)
function toTitleCaseHandlesEmptyInput(logger as Test.Logger) as Boolean {
    Test.assertEqual(LightMenu.toTitleCase(""), "");
    return true;
}
