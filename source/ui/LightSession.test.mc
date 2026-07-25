import Toybox.Lang;
import Toybox.Test;

// Exercises reconcile — re-syncing a live session from a fresh server-truth
// snapshot — directly on the session's state map, so no networking is involved.

(:test)
module LightSessionTest {

    function sessionWith(states as Dictionary<String, Boolean>) as LightSession {
        var state = LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
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
function reconcileConvergesExistingStatesToSnapshot(logger as Test.Logger) as Boolean {
    var session = LightSessionTest.sessionWith({ "light.a" => true, "light.b" => false });

    session.reconcile(LightSessionTest.snapshotOf({ "light.a" => false, "light.b" => true }));

    Test.assert(!session.isOn("light.a"));
    Test.assert(session.isOn("light.b"));
    return true;
}

(:test)
function reconcileOverwritesOptimisticDisagreement(logger as Test.Logger) as Boolean {
    // An optimistic flip (light.x on) that the server never applied is silently
    // overwritten by the snapshot's server truth (off).
    var session = LightSessionTest.sessionWith({ "light.x" => false });
    session.states.put("light.x", true);

    session.reconcile(LightSessionTest.snapshotOf({ "light.x" => false }));

    Test.assert(!session.isOn("light.x"));
    return true;
}

(:test)
function reconcileConvergesFlippedGroupMembers(logger as Test.Logger) as Boolean {
    // A group toggle flips the members on the server; reconcile brings the
    // session's member states in line with that fresh snapshot.
    var session = LightSessionTest.sessionWith({ "light.one" => false, "light.two" => false });

    session.reconcile(LightSessionTest.snapshotOf({ "light.one" => true, "light.two" => true }));

    Test.assert(session.isOn("light.one"));
    Test.assert(session.isOn("light.two"));
    return true;
}

(:test)
function reconcileDoesNotAdoptNewSnapshotKeys(logger as Test.Logger) as Boolean {
    // A snapshot entity absent from the live map is not adopted through
    // reconcile — structural growth is deferred to the next navigation.
    var session = LightSessionTest.sessionWith({ "light.a" => false });

    session.reconcile(LightSessionTest.snapshotOf({ "light.a" => true, "light.new" => true }));

    Test.assert(!session.states.hasKey("light.new"));
    Test.assert(session.isOn("light.a"));
    return true;
}

(:test)
function reconcileKeepsAbsentEntityUntouched(logger as Test.Logger) as Boolean {
    // An entity present in the live map but absent from the snapshot keeps its
    // value rather than being flipped off by isOn's unknown-id default. Its key
    // survives — structural removal is deferred to the next navigation.
    var session = LightSessionTest.sessionWith({ "light.a" => false, "light.gone" => true });

    session.reconcile(LightSessionTest.snapshotOf({ "light.a" => true }));

    Test.assert(session.isOn("light.a"));
    Test.assert(session.isOn("light.gone"));
    Test.assert(session.states.hasKey("light.gone"));
    return true;
}
