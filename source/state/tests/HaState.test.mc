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

    function setStructure(haState as HaState, payload as Dictionary) as Void {
        haState.setZone(HaPayload.parseZone(payload));
        haState.setAreas(HaPayload.parseAreas(payload));
        haState.setFloors(HaPayload.parseFloors(payload));
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
    HaStateTest.setLights(haState, { "light.a" => HaStateTest.light(true, "area.a") });
    Test.assert(!haState.isPending("light.a"));
    return true;
}

(:test)
function arrivingLightsAnswerEveryAssumptionTheyReplace(logger as Test.Logger) as Boolean {
    // Home Assistant reports every light it knows in one payload, so its arrival
    // is truth about all of them — including the one just tapped, whose assumed
    // value has no standing against it. Server truth still reads as off here: a
    // tap whose call has not reached the bulb yet is answered by what HA says,
    // not by what the tap hoped.
    var haState = HaStateTest.stateWithLights({
        "light.a" => HaStateTest.light(false, "area.a"),
        "light.b" => HaStateTest.light(false, "area.a")
    });

    haState.override("light.a", true);
    HaStateTest.setLights(haState, { "light.a" => HaStateTest.light(false, "area.a") });

    Test.assert(!haState.isPending("light.a"));
    Test.assert(!haState.isOn("light.a"));
    Test.assertEqual(haState.getLightsInArea("area.a").size(), 1);
    return true;
}

(:test)
function anAssumptionOutlivesTheReplyAndOnlyAFetchEndsIt(logger as Test.Logger) as Boolean {
    // The service call's reply says the call was accepted, never what the light
    // became, so nothing about it can answer the assumption. Until a fetch lands
    // the row goes on showing what the user asked for.
    var haState = HaStateTest.stateWithLights({ "light.a" => HaStateTest.light(false, "area.a") });

    haState.override("light.a", true);

    Test.assert(haState.isOn("light.a"));
    Test.assert(haState.isPending("light.a"));

    HaStateTest.setLights(haState, { "light.a" => HaStateTest.light(true, "area.a") });

    Test.assert(haState.isOn("light.a"));
    Test.assert(!haState.isPending("light.a"));
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

    haState.override("light.group", true);

    Test.assert(haState.isOn("light.group"));
    Test.assert(haState.isOn("light.one"));
    Test.assert(haState.isOn("light.two"));
    Test.assert(haState.isPending("light.group"));
    Test.assert(haState.isPending("light.one"));
    Test.assert(haState.isPending("light.two"));
    return true;
}

(:test)
function aGroupWithNoMembersStillOverridesItself(logger as Test.Logger) as Boolean {
    // Membership rides on the payload, so a group whose ids never arrived still
    // has a row that must move when it is tapped.
    var haState = HaStateTest.stateWithLights({
        "light.group" => HaStateTest.light(false, "area.a")
    });

    haState.override("light.group", true);

    Test.assert(haState.isOn("light.group"));
    Test.assert(haState.isPending("light.group"));
    return true;
}

(:test)
function anAreasLightsReadCurrentAfterATapRatherThanTheirHandedOutValue(logger as Test.Logger) as Boolean {
    // The indexes hand out the lights themselves, so a caller holding an area's
    // lights across a tap reads the assumption rather than a snapshot from before
    // it.
    var haState = HaStateTest.stateWithLights({ "light.a" => HaStateTest.light(false, "area.a") });
    var held = haState.getLightsInArea("area.a");

    haState.override("light.a", true);

    Test.assert(held[0].isOn());
    Test.assert(held[0].isPending());
    return true;
}

(:test)
function aMemberWithNoEntityOfItsOwnIsStillCalledButNeverReadsAsPending(logger as Test.Logger) as Boolean {
    // Membership expands over the whole group while entities arrive per area, so a
    // member assigned to no area has no state to assume. It stays a service target,
    // and the group's own row is what a second tap is locked out by.
    var haState = HaStateTest.stateWithLights({
        "light.group" => { "state" => false, "area_id" => "area.a", "available" => true,
            "memberIds" => ["light.arealess"] }
    });

    haState.override("light.group", true);

    Test.assertEqual(haState.getToggleTargets("light.group").size(), 2);
    Test.assert(haState.isPending("light.group"));
    Test.assert(!haState.isPending("light.arealess"));
    Test.assert(haState.hasAnyPending(haState.getToggleTargets("light.group")));
    return true;
}

(:test)
function aFloorScopeCoversEveryLightInItsAreasAndNothingOutside(logger as Test.Logger) as Boolean {
    // Home Assistant expands the floor server-side and accepts a call to a light
    // that is currently unreachable, so a group and a dead bulb are both in scope
    // — anything narrower would claim less than the action does. Only the floor's
    // own areas bound it.
    var haState = new HaState();
    HaStateTest.setStructure(haState, {
        "areas" => { "area.kitchen" => { "name" => "Küche" }, "area.hall" => { "name" => "Hall" } },
        "floors" => { "floor.ground" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kitchen", "area.hall"] } }
    });
    HaStateTest.setLights(haState, {
        "light.group" => { "state" => false, "area_id" => "area.kitchen", "available" => true,
            "memberIds" => ["light.kitchen"] },
        "light.kitchen" => HaStateTest.light(false, "area.kitchen"),
        "light.broken" => { "state" => false, "area_id" => "area.kitchen", "available" => false },
        "light.hall" => HaStateTest.light(false, "area.hall"),
        "light.elsewhere" => HaStateTest.light(false, "area.attic")
    });

    haState.overrideFloorLights("floor.ground", true);

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

    Test.assertEqual(haState.getLightsInArea("area.kitchen").size(), 2);
    Test.assertEqual(haState.getLightsInArea("area.bedroom").size(), 1);
    Test.assertEqual(haState.getLightsInArea("area.bedroom")[0].id, "light.bedroom");
    return true;
}

(:test)
function aFloorResolvesOnlyTheAreasTheRegistryStillKnows(logger as Test.Logger) as Boolean {
    // The floor's area list and the area registry arrive on one target but are
    // Home Assistant's to keep in step, so an id it no longer knows yields no
    // area rather than a card the user cannot open.
    var haState = new HaState();
    HaStateTest.setStructure(haState, {
        "areas" => { "area.kept" => { "name" => "Kept" } },
        "floors" => { "floor.g" => { "name" => "Ground", "order" => 0,
            "areas" => ["area.kept", "area.ghost"] } }
    });

    var areas = haState.getAreasInFloor("floor.g");

    Test.assertEqual(areas.size(), 1);
    Test.assertEqual(areas[0].id, "area.kept");
    Test.assertEqual(areas[0].name, "Kept");
    return true;
}

(:test)
function anUnknownAreaOrFloorYieldsAnEmptyCollectionRatherThanNull(logger as Test.Logger) as Boolean {
    // Both mean nothing to render, so a caller says so once.
    var haState = new HaState();

    Test.assertEqual(haState.getLightsInArea("area.ghost").size(), 0);
    Test.assertEqual(haState.getSensorsInArea("area.ghost").size(), 0);
    Test.assertEqual(haState.getLightsInFloor("floor.ghost").size(), 0);
    Test.assertEqual(haState.getAreasInFloor("floor.ghost").size(), 0);
    Test.assertEqual(haState.getAreas().size(), 0);
    return true;
}
