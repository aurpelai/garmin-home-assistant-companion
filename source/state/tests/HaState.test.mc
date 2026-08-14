import Toybox.Lang;
import Toybox.Test;

(:test)
module HaStateTest {

    function stateWithLights(entries as Dictionary) as HaState {
        var haState = new HaState();
        haState.setLights(HaPayload.parseLights({ "lights" => entries }));
        return haState;
    }

    function setLights(haState as HaState, entries as Dictionary) as Void {
        haState.setLights(HaPayload.parseLights({ "lights" => entries }));
    }

    function light(state as Boolean, areaId as String) as Dictionary {
        return { "state" => state, "area_id" => areaId, "available" => true };
    }
}

(:test)
function readResolvesToTheOverrideThenToServerTruth(logger as Test.Logger) as Boolean {
    var haState = HaStateTest.stateWithLights({
        "light.overridden" => HaStateTest.light(false, "area.a"),
        "light.untouched" => HaStateTest.light(true, "area.a")
    });

    haState.override("light.overridden", true);

    Test.assert(haState.isOn("light.overridden"));
    Test.assert(haState.isOn("light.untouched"));
    Test.assert(!haState.isOn("light.absent"));
    return true;
}

(:test)
function pendingIsDerivedFromAnOverrideExisting(logger as Test.Logger) as Boolean {
    // Nothing stores the status, so nothing can disagree with it: an override that
    // assumes the value already held still reads as pending.
    var haState = HaStateTest.stateWithLights({ "light.a" => HaStateTest.light(true, "area.a") });

    Test.assert(!haState.isPending("light.a"));
    haState.override("light.a", true);
    Test.assert(haState.isPending("light.a"));
    haState.clearOverrides(["light.a"]);
    Test.assert(!haState.isPending("light.a"));
    return true;
}

(:test)
function storingATargetReplacesItWholesaleAndLeavesOverridesAlone(logger as Test.Logger) as Boolean {
    // The refresh interleaving case: server truth is replaced, yet the assumed
    // value survives rather than flickering back and forward again.
    var haState = HaStateTest.stateWithLights({
        "light.a" => HaStateTest.light(false, "area.a"),
        "light.b" => HaStateTest.light(false, "area.a")
    });

    haState.override("light.a", true);
    HaStateTest.setLights(haState, { "light.a" => HaStateTest.light(false, "area.a") });

    Test.assert(haState.isPending("light.a"));
    Test.assert(haState.isOn("light.a"));
    Test.assert(haState.getLight("light.b") == null);
    Test.assertEqual(haState.getLightIdsInArea("area.a").size(), 1);
    return true;
}

(:test)
function aRefreshDropsOnlyOverridesWhoseEntityIsGone(logger as Test.Logger) as Boolean {
    var haState = HaStateTest.stateWithLights({
        "light.staying" => HaStateTest.light(false, "area.a"),
        "light.going" => HaStateTest.light(false, "area.a")
    });

    haState.override("light.staying", true);
    haState.override("light.going", true);
    HaStateTest.setLights(haState, { "light.staying" => HaStateTest.light(false, "area.a") });

    Test.assert(haState.isPending("light.staying"));
    Test.assert(!haState.isPending("light.going"));
    return true;
}

(:test)
function clearingAnOverrideThatIsGoneIsANoOp(logger as Test.Logger) as Boolean {
    // A refresh may have dropped an orphan whose service-call reply then arrives,
    // and every terminal outcome clears regardless.
    var haState = HaStateTest.stateWithLights({ "light.a" => HaStateTest.light(false, "area.a") });

    haState.clearOverrides(["light.vanished"]);
    haState.override("light.a", true);
    haState.clearOverrides(["light.a", "light.vanished"]);

    Test.assert(!haState.isPending("light.a"));
    Test.assert(!haState.isOn("light.a"));
    return true;
}

(:test)
function aGroupScopeFansOutToItsMemberIds(logger as Test.Logger) as Boolean {
    // The group's own entity is left out deliberately; its row waits for the
    // refresh.
    var haState = HaStateTest.stateWithLights({
        "light.group" => { "state" => false, "area_id" => "area.a", "available" => true,
            "memberIds" => ["light.one", "light.two"] },
        "light.one" => HaStateTest.light(false, "area.a"),
        "light.two" => HaStateTest.light(false, "area.a")
    });

    var overridden = haState.overrideGroup("light.group", true);

    Test.assertEqual(overridden.size(), 2);
    Test.assert(haState.isOn("light.one"));
    Test.assert(haState.isOn("light.two"));
    Test.assert(!haState.isPending("light.group"));
    return true;
}

(:test)
function theOverriddenIdsBelongToTheCallerNotToServerTruth(logger as Test.Logger) as Boolean {
    // The group path is the one that could hand back LightModel.memberIds itself,
    // so mutating what comes out must not rewrite the group's membership.
    var haState = HaStateTest.stateWithLights({
        "light.group" => { "state" => false, "area_id" => "area.a", "available" => true,
            "memberIds" => ["light.one"] },
        "light.one" => HaStateTest.light(false, "area.a")
    });

    var overridden = haState.overrideGroup("light.group", true);
    overridden.add("light.intruder");

    Test.assertEqual(((haState.getLight("light.group") as LightModel).memberIds as Array<String>).size(), 1);
    Test.assert(!haState.isPending("light.intruder"));
    return true;
}

(:test)
function aFloorScopeExcludesGroupsAndUnavailableEntities(logger as Test.Logger) as Boolean {
    // Home Assistant expands the floor itself, so overriding a group would double
    // count its members; an unavailable light cannot be reached at all.
    var haState = new HaState();
    haState.setStructure(HaPayload.parseStructure({
        "areas" => { "area.kitchen" => { "name" => "Küche" }, "area.hall" => { "name" => "Hall" } },
        "floors" => { "floor.ground" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kitchen", "area.hall"] } }
    }));
    HaStateTest.setLights(haState, {
        "light.group" => { "state" => false, "area_id" => "area.kitchen", "available" => true,
            "memberIds" => ["light.kitchen"] },
        "light.kitchen" => HaStateTest.light(false, "area.kitchen"),
        "light.broken" => { "state" => false, "area_id" => "area.kitchen", "available" => false },
        "light.hall" => HaStateTest.light(false, "area.hall"),
        "light.elsewhere" => HaStateTest.light(false, "area.attic")
    });

    var overridden = haState.overrideFloorLights("floor.ground", true);

    Test.assertEqual(overridden.size(), 2);
    Test.assert(haState.isOn("light.kitchen"));
    Test.assert(haState.isOn("light.hall"));
    Test.assert(!haState.isPending("light.group"));
    Test.assert(!haState.isPending("light.broken"));
    Test.assert(!haState.isPending("light.elsewhere"));
    return true;
}
