import Toybox.Lang;
import Toybox.Test;

(:test)
module HaStateTest {

    function stateWithLights(entries as Dictionary) as HaState {
        var haState = new HaState();
        haState.setToggleables(Domain.LIGHT, HaPayload.parseLights({ "lights" => entries }));
        return haState;
    }

    function setLights(haState as HaState, entries as Dictionary) as Void {
        haState.setToggleables(Domain.LIGHT, HaPayload.parseLights({ "lights" => entries }));
    }

    function stateWithFans(entries as Dictionary) as HaState {
        var haState = new HaState();
        haState.setToggleables(Domain.FAN, HaPayload.parseFans({ "fans" => entries }));
        return haState;
    }

    function setFans(haState as HaState, entries as Dictionary) as Void {
        haState.setToggleables(Domain.FAN, HaPayload.parseFans({ "fans" => entries }));
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

    function fan(state as Boolean, areaId as String) as Dictionary {
        return { "state" => state, "area_id" => areaId, "available" => true, "speed" => "50 %" };
    }
}

(:test)
function anOverrideDrivesAFanExactlyAsItDrivesALight(logger as Test.Logger) as Boolean {
    var haState = HaStateTest.stateWithFans({ "fan.a" => HaStateTest.fan(false, "area.a") });

    Test.assert(!haState.isOn("fan.a"));
    Test.assert(!haState.isPending("fan.a"));

    haState.override("fan.a", true);

    Test.assert(haState.isOn("fan.a"));
    Test.assert(haState.isPending("fan.a"));
    Test.assert(haState.hasAnyPending(haState.getToggleTargets("fan.a")));

    HaStateTest.setFans(haState, { "fan.a" => HaStateTest.fan(true, "area.a") });

    Test.assert(haState.isOn("fan.a"));
    Test.assert(!haState.isPending("fan.a"));
    return true;
}

(:test)
function aFanGroupScopeCoversTheGroupItselfAndItsMembers(logger as Test.Logger) as Boolean {
    var haState = HaStateTest.stateWithFans({
        "fan.group" => { "state" => false, "area_id" => "area.a", "available" => true,
            "memberIds" => ["fan.one", "fan.two"] },
        "fan.one" => HaStateTest.fan(false, "area.a"),
        "fan.two" => HaStateTest.fan(false, "area.a")
    });

    haState.override("fan.group", true);

    Test.assertEqual(haState.getToggleTargets("fan.group").size(), 3);
    Test.assert(haState.isOn("fan.group"));
    Test.assert(haState.isOn("fan.one"));
    Test.assert(haState.isOn("fan.two"));
    Test.assert(haState.isPending("fan.two"));
    return true;
}

(:test)
function anAreaIsReadOneDomainAtATime(logger as Test.Logger) as Boolean {
    var haState = HaStateTest.stateWithLights({ "light.a" => HaStateTest.light(true, "area.a") });
    HaStateTest.setFans(haState, { "fan.a" => HaStateTest.fan(false, "area.a") });

    haState.override("fan.a", true);

    Test.assert(haState.isOn("fan.a"));
    Test.assert(haState.isPending("fan.a"));
    Test.assert(haState.isOn("light.a"));
    Test.assert(!haState.isPending("light.a"));
    Test.assertEqual(haState.getToggleablesInArea("area.a", Domain.LIGHT).size(), 1);
    Test.assertEqual(haState.getToggleablesInArea("area.a", Domain.FAN).size(), 1);
    Test.assertEqual(haState.getToggleablesInArea("area.a", Domain.FAN)[0].id, "fan.a");
    return true;
}

(:test)
function aFetchOfOneDomainReplacesOnlyThatDomain(logger as Test.Logger) as Boolean {
    var haState = HaStateTest.stateWithLights({
        "light.a" => HaStateTest.light(true, "area.a"),
        "light.gone" => HaStateTest.light(true, "area.a")
    });
    HaStateTest.setFans(haState, { "fan.a" => HaStateTest.fan(false, "area.a") });

    haState.override("fan.a", true);
    HaStateTest.setLights(haState, { "light.a" => HaStateTest.light(false, "area.a") });

    Test.assertEqual(haState.getToggleablesInArea("area.a", Domain.LIGHT).size(), 1);
    Test.assert(!haState.isOn("light.a"));
    Test.assert(!haState.isOn("light.gone"));
    Test.assertEqual(haState.getToggleablesInArea("area.a", Domain.FAN).size(), 1);
    Test.assert(haState.isOn("fan.a"));
    Test.assert(haState.isPending("fan.a"));
    return true;
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
    Test.assertEqual(haState.getToggleablesInArea("area.a", Domain.LIGHT).size(), 1);
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
    var held = haState.getToggleablesInArea("area.a", Domain.LIGHT);

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
    HaStateTest.setFans(haState, { "fan.kitchen" => HaStateTest.fan(false, "area.kitchen") });

    haState.overrideFloorLights("floor.ground", true);

    Test.assert(haState.isOn("light.group"));
    Test.assert(haState.isOn("light.kitchen"));
    Test.assert(haState.isOn("light.broken"));
    Test.assert(haState.isOn("light.hall"));
    Test.assert(!haState.isPending("light.elsewhere"));
    Test.assert(!haState.isPending("fan.kitchen"));
    Test.assertEqual(haState.getToggleablesInFloor("floor.ground", Domain.LIGHT).size(), 4);
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

    Test.assertEqual(haState.getToggleablesInArea("area.kitchen", Domain.LIGHT).size(), 2);
    Test.assertEqual(haState.getToggleablesInArea("area.bedroom", Domain.LIGHT).size(), 1);
    Test.assertEqual(haState.getToggleablesInArea("area.bedroom", Domain.LIGHT)[0].id, "light.bedroom");
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

    Test.assertEqual(haState.getToggleablesInArea("area.ghost", Domain.LIGHT).size(), 0);
    Test.assertEqual(haState.getToggleablesInArea("area.ghost", Domain.FAN).size(), 0);
    Test.assertEqual(haState.getSensorsInArea("area.ghost").size(), 0);
    Test.assertEqual(haState.getToggleablesInFloor("floor.ghost", Domain.LIGHT).size(), 0);
    Test.assertEqual(haState.getAreasInFloor("floor.ghost").size(), 0);
    Test.assertEqual(haState.getAreas().size(), 0);
    return true;
}
