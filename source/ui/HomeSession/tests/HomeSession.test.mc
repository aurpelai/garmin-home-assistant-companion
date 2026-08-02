import Toybox.Lang;
import Toybox.Test;

// Async branches are driven by firing FakeHaClient's captured callback, so no
// live network is involved.

(:test)
module HomeSessionTest {

    function sessionWith(states as Dictionary<String, Boolean>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new HomeSession(new HaClient(), state);
    }

    function stateOf(states as Dictionary<String, Boolean>) as HomeState {
        return HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
    }

    function fakeSessionWith(states as Dictionary<String, Boolean>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new HomeSession(new FakeHaClient(), state);
    }

    function sessionWithAvailable(states as Dictionary<String, Boolean>,
                                 available as Dictionary<String, Boolean>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "available" => available
        });
        return new HomeSession(new HaClient(), state);
    }

    // A one-area floor "Upstairs" carrying the given light states, backed by the
    // FakeHaClient so the floor service callback can be fired synchronously.
    function fakeFloorSessionWith(states as Dictionary<String, Boolean>) as HomeSession {
        var state = HomeState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states,
            "floors" => [{ "id" => "floor_up", "name" => "Upstairs", "areas" => ["Room"] }]
        });
        return new HomeSession(new FakeHaClient(), state);
    }
}

// A no-op completion for tests that only care about the optimistic flip.
(:test)
class NoopCompletion {
    function onComplete() as Void {
    }
}

(:test)
function applyStateConvergesExistingStatesToServerTruth(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.sessionWith({ "light.a" => true, "light.b" => false });

    session.applyState(HomeSessionTest.stateOf({ "light.a" => false, "light.b" => true }));

    Test.assert(!session.isOn("light.a"));
    Test.assert(session.isOn("light.b"));
    return true;
}

(:test)
function applyStateOverwritesOptimisticDisagreement(logger as Test.Logger) as Boolean {
    // An optimistic flip (light.x on) that the server never applied is silently
    // overwritten by the fresh state's server truth (off).
    var session = HomeSessionTest.sessionWith({ "light.x" => false });
    session.toggleState("light.x", new NoopCompletion().method(:onComplete));

    session.applyState(HomeSessionTest.stateOf({ "light.x" => false }));

    Test.assert(!session.isOn("light.x"));
    return true;
}

(:test)
function applyStateConvergesFlippedGroupMembers(logger as Test.Logger) as Boolean {
    // A group toggle flips the members on the server; applyState brings the
    // session's member states in line with that fresh state.
    var session = HomeSessionTest.sessionWith({ "light.one" => false, "light.two" => false });

    session.applyState(HomeSessionTest.stateOf({ "light.one" => true, "light.two" => true }));

    Test.assert(session.isOn("light.one"));
    Test.assert(session.isOn("light.two"));
    return true;
}

(:test)
function applyStateDoesNotAdoptNewStateKeys(logger as Test.Logger) as Boolean {
    // An entity absent from the live map is not adopted through applyState —
    // structural growth is deferred to the next navigation.
    var session = HomeSessionTest.sessionWith({ "light.a" => false });

    session.applyState(HomeSessionTest.stateOf({ "light.a" => true, "light.new" => true }));

    Test.assert(!session.isTracked("light.new"));
    Test.assert(session.isOn("light.a"));
    return true;
}

(:test)
function applyStateKeepsAbsentEntityUntouched(logger as Test.Logger) as Boolean {
    // An entity present in the live map but absent from the fresh state keeps
    // its value rather than being flipped off by isOn's unknown-id default. Its
    // key survives — structural removal is deferred to the next navigation.
    var session = HomeSessionTest.sessionWith({ "light.a" => false, "light.gone" => true });

    session.applyState(HomeSessionTest.stateOf({ "light.a" => true }));

    Test.assert(session.isOn("light.a"));
    Test.assert(session.isOn("light.gone"));
    Test.assert(session.isTracked("light.gone"));
    return true;
}

(:test)
function toggleStateRevertsOptimisticFlipOnFailure(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeSessionWith({ "light.a" => false });
    var spy = new CompletionSpy();

    session.toggleState("light.a", spy.method(:onComplete));
    Test.assert(session.isOn("light.a"));   // flipped optimistically

    (session.client as FakeHaClient).fireServiceFailure();

    Test.assert(!session.isOn("light.a"));   // reverted
    Test.assert(spy.fired);
    return true;
}

(:test)
function toggleStateFiresExactlyOneServiceCall(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeSessionWith({ "light.a" => false });

    session.toggleState("light.a", new NoopCompletion().method(:onComplete));

    Test.assertEqual((session.client as FakeHaClient).toggleCount, 1);
    Test.assert(session.isOn("light.a"));
    return true;
}

(:test)
function toggleStateKeepsFlipOnSuccess(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeSessionWith({ "light.a" => false });
    var spy = new CompletionSpy();

    session.toggleState("light.a", spy.method(:onComplete));
    (session.client as FakeHaClient).fireServiceSuccess();

    Test.assert(session.isOn("light.a"));
    Test.assert(spy.fired);
    return true;
}

(:test)
function refreshStateHealsOptimisticDisagreementOnSuccess(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeSessionWith({ "light.a" => false });
    session.toggleState("light.a", new NoopCompletion().method(:onComplete));
    var spy = new CompletionSpy();

    session.refreshState(spy.method(:onDone));
    (session.client as FakeHaClient).fireFetchSuccess(HomeSessionTest.stateOf({ "light.a" => false }));

    Test.assert(!session.isOn("light.a"));
    Test.assert(spy.fired);
    return true;
}

(:test)
function refreshStateCorrectsActionThatDidNotTakeEffect(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeSessionWith({ "light.a" => false });
    session.toggleState("light.a", new NoopCompletion().method(:onComplete));
    // The service call reports success, but HA's actual state never moved —
    // only the later reconciling re-fetch can catch that, not this response.
    (session.client as FakeHaClient).fireServiceSuccess();
    Test.assert(session.isOn("light.a"));

    var spy = new CompletionSpy();
    session.refreshState(spy.method(:onDone));
    (session.client as FakeHaClient).fireFetchSuccess(HomeSessionTest.stateOf({ "light.a" => false }));

    Test.assert(!session.isOn("light.a"));
    Test.assert(spy.fired);
    return true;
}

(:test)
function refreshStateSwallowsFailureButStillCompletes(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeSessionWith({ "light.a" => true });
    var spy = new CompletionSpy();

    session.refreshState(spy.method(:onDone));
    (session.client as FakeHaClient).fireFetchFailure();

    Test.assert(session.isOn("light.a"));   // last-known state survives
    Test.assert(spy.fired);
    return true;
}

(:test)
function isAvailableMirrorsServerTruthUnaffectedByToggle(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.sessionWithAvailable(
        { "light.a" => false, "light.down" => false },
        { "light.a" => true, "light.down" => false });
    Test.assert(session.isAvailable("light.a"));
    Test.assert(!session.isAvailable("light.down"));

    session.toggleState("light.a", new NoopCompletion().method(:onComplete));
    session.toggleState("light.down", new NoopCompletion().method(:onComplete));

    Test.assert(session.isAvailable("light.a"));
    Test.assert(!session.isAvailable("light.down"));
    return true;
}

(:test)
function areFloorLightsOnIsTrueWhenAnyLightOn(logger as Test.Logger) as Boolean {
    var allOff = HomeSessionTest.fakeFloorSessionWith({ "light.a" => false, "light.b" => false });
    Test.assert(!allOff.areFloorLightsOn("Upstairs"));

    var oneOn = HomeSessionTest.fakeFloorSessionWith({ "light.a" => true, "light.b" => false });
    Test.assert(oneOn.areFloorLightsOn("Upstairs"));
    return true;
}

(:test)
function toggleFloorLightsTurnsAllOnWhenAllOff(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeFloorSessionWith({ "light.a" => false, "light.b" => false });

    session.toggleFloorLights("floor_up", "Upstairs", new NoopCompletion().method(:onComplete));

    Test.assert(session.isOn("light.a"));
    Test.assert(session.isOn("light.b"));
    Test.assertEqual((session.client as FakeHaClient).lastFloorService as String, "turn_on");
    return true;
}

(:test)
function toggleFloorLightsTurnsAllOffWhenAnyOn(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeFloorSessionWith({ "light.a" => true, "light.b" => false });

    session.toggleFloorLights("floor_up", "Upstairs", new NoopCompletion().method(:onComplete));

    Test.assert(!session.isOn("light.a"));
    Test.assert(!session.isOn("light.b"));
    Test.assertEqual((session.client as FakeHaClient).lastFloorService as String, "turn_off");
    return true;
}

(:test)
function toggleFloorLightsFiresExactlyOneFloorCall(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeFloorSessionWith({ "light.a" => false, "light.b" => false });

    session.toggleFloorLights("floor_up", "Upstairs", new NoopCompletion().method(:onComplete));

    Test.assertEqual((session.client as FakeHaClient).floorToggleCount, 1);
    return true;
}

(:test)
function toggleFloorLightsRestoresEachLightToItsOwnPriorStateOnFailure(logger as Test.Logger) as Boolean {
    // The bug-fix guard: a mixed floor (one on, one off) toggled then failed
    // must return EACH light to its ORIGINAL value — not a blanket flip, and not
    // a floorId-as-entity revert that leaves the members wrong.
    var session = HomeSessionTest.fakeFloorSessionWith({ "light.on" => true, "light.off" => false });

    session.toggleFloorLights("floor_up", "Upstairs", new NoopCompletion().method(:onComplete));
    // Any-on -> turn all off: both flip to off optimistically.
    Test.assert(!session.isOn("light.on"));
    Test.assert(!session.isOn("light.off"));

    (session.client as FakeHaClient).fireServiceFailure();

    Test.assert(session.isOn("light.on"));    // restored to its original ON
    Test.assert(!session.isOn("light.off"));  // restored to its original OFF
    return true;
}

(:test)
function toggleFloorLightsKeepsFlipsOnSuccess(logger as Test.Logger) as Boolean {
    var session = HomeSessionTest.fakeFloorSessionWith({ "light.a" => false, "light.b" => false });
    var spy = new CompletionSpy();

    session.toggleFloorLights("floor_up", "Upstairs", spy.method(:onComplete));
    (session.client as FakeHaClient).fireServiceSuccess();

    Test.assert(session.isOn("light.a"));
    Test.assert(session.isOn("light.b"));
    Test.assert(spy.fired);
    return true;
}
