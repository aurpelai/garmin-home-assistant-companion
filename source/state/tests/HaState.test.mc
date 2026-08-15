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
function aGroupScopeCoversTheGroupItselfAndItsMembers(logger as Test.Logger) as Boolean {
    // The row the user tapped is the group's own, so leaving it out would show
    // the members moving while the row that moved them sat stale.
    var haState = HaStateTest.stateWithLights({
        "light.group" => { "state" => false, "area_id" => "area.a", "available" => true,
            "memberIds" => ["light.one", "light.two"] },
        "light.one" => HaStateTest.light(false, "area.a"),
        "light.two" => HaStateTest.light(false, "area.a")
    });

    var overridden = haState.override("light.group", true);

    Test.assertEqual(overridden.size(), 3);
    Test.assert(haState.isOn("light.group"));
    Test.assert(haState.isOn("light.one"));
    Test.assert(haState.isOn("light.two"));
    Test.assert(haState.isPending("light.group"));
    return true;
}

(:test)
function aGroupWithNoMembersStillOverridesItself(logger as Test.Logger) as Boolean {
    // Membership rides on the payload, so a group whose ids never arrived still
    // has a row that must move when it is tapped.
    var haState = HaStateTest.stateWithLights({
        "light.group" => HaStateTest.light(false, "area.a")
    });

    Test.assertEqual(haState.override("light.group", true).size(), 1);
    Test.assert(haState.isOn("light.group"));
    return true;
}

(:test)
function theOverriddenIdsBelongToTheCallerNotToServerTruth(logger as Test.Logger) as Boolean {
    // The caller holds these until its reply settles, so mutating them must not
    // rewrite a group's membership or create an override nobody asked for.
    var haState = HaStateTest.stateWithLights({
        "light.group" => { "state" => false, "area_id" => "area.a", "available" => true,
            "memberIds" => ["light.one"] },
        "light.one" => HaStateTest.light(false, "area.a")
    });

    var overridden = haState.override("light.group", true);
    overridden.add("light.intruder");

    Test.assertEqual(((haState.getLight("light.group") as LightModel).memberIds as Array<String>).size(), 1);
    Test.assert(!haState.isPending("light.intruder"));
    return true;
}

(:test)
function aFloorScopeCoversEveryLightInItsAreasAndNothingOutside(logger as Test.Logger) as Boolean {
    // Home Assistant expands the floor server-side and accepts a call to a light
    // that is currently unreachable, so a group and a dead bulb are both in scope
    // — anything narrower would claim less than the action does. Only the floor's
    // own areas bound it.
    var haState = new HaState();
    haState.setZone(HaPayload.parseZone({
        "areas" => { "area.kitchen" => { "name" => "Küche" }, "area.hall" => { "name" => "Hall" } },
        "floors" => { "floor.ground" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kitchen", "area.hall"] } }
    }));
    haState.setAreas(HaPayload.parseAreas({
        "areas" => { "area.kitchen" => { "name" => "Küche" }, "area.hall" => { "name" => "Hall" } },
        "floors" => { "floor.ground" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kitchen", "area.hall"] } }
    }));
    haState.setFloors(HaPayload.parseFloors({
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

    Test.assertEqual(overridden.size(), 4);
    Test.assert(haState.isOn("light.group"));
    Test.assert(haState.isOn("light.kitchen"));
    Test.assert(haState.isOn("light.broken"));
    Test.assert(haState.isOn("light.hall"));
    Test.assert(!haState.isPending("light.elsewhere"));
    return true;
}

(:test)
function areaMembershipIsIndexedFromEachEntitysOwnAreaId(logger as Test.Logger) as Boolean {
    // The payload carries an area per entity rather than an entity list per
    // area, so the index every area screen reads is built on the write.
    var haState = new HaState();
    HaStateTest.setLights(haState, {
        "light.kitchen_ceiling" => HaStateTest.light(true, "area.kitchen"),
        "light.kitchen_counter" => HaStateTest.light(false, "area.kitchen"),
        "light.bedroom" => HaStateTest.light(false, "area.bedroom")
    });

    Test.assertEqual(haState.getLightIdsInArea("area.kitchen").size(), 2);
    Test.assertEqual(haState.getLightIdsInArea("area.bedroom").size(), 1);
    Test.assertEqual(haState.getLightIdsInArea("area.bedroom")[0], "light.bedroom");
    return true;
}
