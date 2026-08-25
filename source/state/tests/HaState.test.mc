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

    function unavailableLight(areaId as String) as Dictionary {
        return { "state" => false, "area_id" => areaId, "available" => false };
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
    var haState = HaStateTest.stateWithLights({ "light.a" => HaStateTest.light(false, "area.a") });
    var held = haState.getLightsInArea("area.a");

    haState.override("light.a", true);

    Test.assert(held[0].isOn());
    Test.assert(held[0].isPending());
    return true;
}

(:test)
function aMemberWithNoEntityOfItsOwnIsStillCalledButNeverReadsAsPending(logger as Test.Logger) as Boolean {
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
    // UNVERIFIED: Home Assistant expands a floor server-side and accepts a call
    // to a light that is currently unreachable.
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
    var haState = new HaState();

    Test.assertEqual(haState.getLightsInArea("area.ghost").size(), 0);
    Test.assertEqual(haState.getSensorsInArea("area.ghost").size(), 0);
    Test.assertEqual(haState.getLightsInFloor("floor.ghost").size(), 0);
    Test.assertEqual(haState.getAreasInFloor("floor.ghost").size(), 0);
    Test.assertEqual(haState.getAreas().size(), 0);
    return true;
}

(:test)
function lightAggregatesDefaultToEmptyBeforeAFetch(logger as Test.Logger) as Boolean {
    var haState = new HaState();

    Test.assert(haState.getHomeLightSummary() == null);
    Test.assert(haState.getLightSummary("floor.ghost") == null);
    Test.assertEqual(haState.getLightCount("area.ghost").available, 0);
    Test.assertEqual(haState.getLightCount("area.ghost").on, 0);
    return true;
}

(:test)
function areaAndFloorMeansDoNotCollideOnAnIdTheyShare(logger as Test.Logger) as Boolean {
    var haState = new HaState();

    haState.setSensorAggregates(
        { "shared" => { "temperature" => "18.0 °C" } },
        { "shared" => { "temperature" => "22.0 °C" } },
        { "temperature" => "20.0 °C" });

    Test.assert((haState.getAreaAverages("shared").get("temperature") as String).equals("18.0 °C"));
    Test.assert((haState.getFloorAverages("shared").get("temperature") as String).equals("22.0 °C"));
    Test.assert((haState.getHomeAverages().get("temperature") as String).equals("20.0 °C"));
    Test.assertEqual(haState.getAreaAverages("ghost").size(), 0);
    return true;
}
