import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Tests for the two seams #5 introduces in the light menu: a row's initial
// switch position, and the post-toggle settle that reconciles the switch to the
// store and restores the resting sublabel. State is controlled directly on the
// store (states map) so no networking is exercised.

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
    // Store already reflects the successful toggle (light is now on). Completing
    // must leave the switch on and clear the in-flight note back to idle.
    var store = LightMenuTest.storeWith({ "light.x" => true });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, store, "light.x", null).onComplete();

    Test.assert(item.isEnabled());
    Test.assert(item.getSubLabel() == null);
    return true;
}

(:test)
function switchFlipsBackAfterFailedToggle(logger as Test.Logger) as Boolean {
    // A failed toggle: the store reverted to off, but the native switch is still
    // showing on (it auto-flipped on tap). Completing must snap it back to off.
    var store = LightMenuTest.storeWith({ "light.x" => false });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, store, "light.x", null).onComplete();

    Test.assert(!item.isEnabled());
    Test.assert(item.getSubLabel() == null);
    return true;
}

(:test)
function idleSubLabelRestoredAfterToggle(logger as Test.Logger) as Boolean {
    // The idle sublabel (empty today, a count under #4) is restored verbatim,
    // not blindly cleared.
    var store = LightMenuTest.storeWith({ "light.x" => true });
    var item = new WatchUi.ToggleMenuItem("X", "Toggling…", "light.x", true, null);

    new ToggleHandler(item, store, "light.x", "3 lights").onComplete();

    Test.assertEqual(item.getSubLabel() as String, "3 lights");
    return true;
}
