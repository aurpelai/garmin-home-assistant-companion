import Toybox.Lang;
import Toybox.Test;

// Exercises applyState — re-syncing a live session from a fresh server-truth
// LightState — directly on the session's state map, so no networking is involved.

(:test)
module LightSessionTest {

    function sessionWith(states as Dictionary<String, Boolean>) as LightSession {
        var state = LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
        return new LightSession(new HaClient(), state);
    }

    function stateOf(states as Dictionary<String, Boolean>) as LightState {
        return LightState.fromTemplateData({
            "areas" => { "Room" => states.keys() },
            "states" => states
        });
    }
}

(:test)
function applyStateConvergesExistingStatesToServerTruth(logger as Test.Logger) as Boolean {
    var session = LightSessionTest.sessionWith({ "light.a" => true, "light.b" => false });

    session.applyState(LightSessionTest.stateOf({ "light.a" => false, "light.b" => true }));

    Test.assert(!session.isOn("light.a"));
    Test.assert(session.isOn("light.b"));
    return true;
}

(:test)
function applyStateOverwritesOptimisticDisagreement(logger as Test.Logger) as Boolean {
    // An optimistic flip (light.x on) that the server never applied is silently
    // overwritten by the fresh state's server truth (off).
    var session = LightSessionTest.sessionWith({ "light.x" => false });
    session.states.put("light.x", true);

    session.applyState(LightSessionTest.stateOf({ "light.x" => false }));

    Test.assert(!session.isOn("light.x"));
    return true;
}

(:test)
function applyStateConvergesFlippedGroupMembers(logger as Test.Logger) as Boolean {
    // A group toggle flips the members on the server; applyState brings the
    // session's member states in line with that fresh state.
    var session = LightSessionTest.sessionWith({ "light.one" => false, "light.two" => false });

    session.applyState(LightSessionTest.stateOf({ "light.one" => true, "light.two" => true }));

    Test.assert(session.isOn("light.one"));
    Test.assert(session.isOn("light.two"));
    return true;
}

(:test)
function applyStateDoesNotAdoptNewStateKeys(logger as Test.Logger) as Boolean {
    // An entity absent from the live map is not adopted through applyState —
    // structural growth is deferred to the next navigation.
    var session = LightSessionTest.sessionWith({ "light.a" => false });

    session.applyState(LightSessionTest.stateOf({ "light.a" => true, "light.new" => true }));

    Test.assert(!session.states.hasKey("light.new"));
    Test.assert(session.isOn("light.a"));
    return true;
}

(:test)
function applyStateKeepsAbsentEntityUntouched(logger as Test.Logger) as Boolean {
    // An entity present in the live map but absent from the fresh state keeps
    // its value rather than being flipped off by isOn's unknown-id default. Its
    // key survives — structural removal is deferred to the next navigation.
    var session = LightSessionTest.sessionWith({ "light.a" => false, "light.gone" => true });

    session.applyState(LightSessionTest.stateOf({ "light.a" => true }));

    Test.assert(session.isOn("light.a"));
    Test.assert(session.isOn("light.gone"));
    Test.assert(session.states.hasKey("light.gone"));
    return true;
}
