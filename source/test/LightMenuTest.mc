import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Exercises the light-menu row seams directly on the store's state map, so no
// networking is involved.

module LightMenuTest {

    function storeWith(states as Dictionary<String, Boolean>) as LightStore {
        var snapshot = LightSnapshot.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new LightStore(new HaClient(), snapshot);
    }
}

(:test)
function rowSwitchReflectsIsOnWhenBuilt(logger as Test.Logger) as Boolean {
    var store = LightMenuTest.storeWith({ "light.on" => true, "light.off" => false });

    Test.assert(LightMenu.makeItem(store, "light.on").isEnabled());
    Test.assert(!LightMenu.makeItem(store, "light.off").isEnabled());
    return true;
}

(:test)
function switchStaysOnAfterSuccessfulToggle(logger as Test.Logger) as Boolean {
    var store = LightMenuTest.storeWith({ "light.x" => true });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, store, "light.x", null).onComplete();

    Test.assert(item.isEnabled());
    Test.assert(item.getSubLabel() == null);
    return true;
}

(:test)
function switchFlipsBackAfterFailedToggle(logger as Test.Logger) as Boolean {
    // Switch still shows on (auto-flipped on tap); store reverted to off.
    var store = LightMenuTest.storeWith({ "light.x" => false });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, store, "light.x", null).onComplete();

    Test.assert(!item.isEnabled());
    Test.assert(item.getSubLabel() == null);
    return true;
}

(:test)
function idleSubLabelRestoredAfterToggle(logger as Test.Logger) as Boolean {
    var store = LightMenuTest.storeWith({ "light.x" => true });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, store, "light.x", "3 lights").onComplete();

    Test.assertEqual(item.getSubLabel() as String, "3 lights");
    return true;
}
