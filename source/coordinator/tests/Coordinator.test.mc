import Toybox.Lang;
import Toybox.Test;

// Captures the coordinator's own outgoing calls instead of making a web
// request, so a test can drive replies synchronously and assert what the
// coordinator asked for.
(:test)
class FakeCoordinatorClient extends HaClient {
    public var refreshCount as Number = 0;
    public var cancelCount as Number = 0;
    public var toggledEntityIds as Array<String> = [];
    public var toggledFloorIds as Array<String> = [];
    public var toggledFloorServices as Array<String> = [];
    private var _onTarget as Method?;
    private var _toggleCallbacks as Array<Method> = [];
    private var _msSinceLastRefresh as Number or Null = null;

    function initialize() {
        HaClient.initialize();
    }

    function refresh(onTarget as Method) as Void {
        refreshCount++;
        _onTarget = onTarget;
    }

    function queueLightToggle(entityId as String, callback as Method) as Void {
        toggledEntityIds.add(entityId);
        _toggleCallbacks.add(callback);
    }

    function queueFloorLights(floorId as String, service as String, callback as Method) as Void {
        toggledFloorIds.add(floorId);
        toggledFloorServices.add(service);
        _toggleCallbacks.add(callback);
    }

    function cancelAll() as Void {
        cancelCount++;
    }

    function msSinceLastRefresh() as Number or Null {
        return _msSinceLastRefresh;
    }

    function setMsSinceLastRefresh(value as Number or Null) as Void {
        _msSinceLastRefresh = value;
    }

    function fireTarget(target as Symbol, result as Object or Null, error as Number or Null) as Void {
        (_onTarget as Method).invoke(target, result, error);
    }

    function fireToggleSuccessAt(index as Number) as Void {
        _toggleCallbacks[index].invoke(true, null);
    }

    function fireToggleFailureAt(index as Number, code as Number) as Void {
        _toggleCallbacks[index].invoke(null, code);
    }
}

(:test)
function rebuildDiscardsStateAndRefetchesRatherThanComparingValues(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:lights, { "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } } }, null);
    coordinator.toggleEntity("light.a");

    // light.a now has an override, still unanswered: were the old HaState
    // merely reconciled rather than thrown away, this override would carry
    // over and the tap below would still read as pending and be ignored.
    coordinator.onSettingsChanged();

    Test.assertEqual(client.cancelCount, 1);
    Test.assertEqual(client.refreshCount, 2);

    coordinator.toggleEntity("light.a");
    Test.assertEqual(client.toggledEntityIds.size(), 2);
    return true;
}

(:test)
function aStaleHideDoesNotClearAViewAlreadyReplacedAsCurrent(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    client.setMsSinceLastRefresh(0);
    var coordinator = new Coordinator(client);
    var departing = {};
    var arriving = {};

    coordinator.onViewShown(departing);
    coordinator.onViewShown(arriving);

    // A stale hide arriving after arriving already took over must not clear
    // it: the clear only applies if the current-view fact still points at
    // the view that is hiding.
    coordinator.onViewHidden(departing);
    Test.assert(coordinator.currentView() == arriving);

    coordinator.onViewHidden(arriving);
    Test.assert(coordinator.currentView() == null);
    return true;
}

(:test)
function toggleRecordsAnOverrideFiresAndTheReplyClearsExactlyThoseIds(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:lights, {
        "lights" => {
            "light.a" => { "state" => false, "area_id" => "area.x" },
            "light.b" => { "state" => false, "area_id" => "area.x" }
        }
    }, null);

    coordinator.toggleEntity("light.a");

    Test.assertEqual(client.toggledEntityIds.size(), 1);
    Test.assertEqual(client.toggledEntityIds[0], "light.a");

    // A second tap while the first is still outstanding is ignored: one
    // in-flight change per entity, regardless of what created it.
    coordinator.toggleEntity("light.a");
    Test.assertEqual(client.toggledEntityIds.size(), 1);

    client.fireToggleSuccessAt(0);

    // The reply's own refresh trigger fires once the override it created is
    // cleared, so a fresh tap is accepted again.
    coordinator.toggleEntity("light.a");
    Test.assertEqual(client.toggledEntityIds.size(), 2);

    // A failed reply clears its own override too: nothing to restore, since
    // server truth was never overwritten.
    coordinator.toggleEntity("light.b");
    client.fireToggleFailureAt(client.toggledEntityIds.size() - 1, -1);
    coordinator.toggleEntity("light.b");
    Test.assertEqual(client.toggledEntityIds.size(), 4);
    return true;
}

(:test)
function toggleFloorLightsFlipsToOnWhenAllAreOffAndQueuesTheFloorTarget(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(:lights, {
        "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } }
    }, null);

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorIds.size(), 1);
    Test.assertEqual(client.toggledFloorIds[0], "floor.up");
    Test.assertEqual(client.toggledFloorServices[0], "turn_on");
    return true;
}

(:test)
function toggleFloorLightsFlipsToOffWhenAnyIsOn(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(:lights, {
        "lights" => {
            "light.a" => { "state" => false, "area_id" => "area.x" },
            "light.b" => { "state" => true, "area_id" => "area.x" }
        }
    }, null);

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorServices[0], "turn_off");
    return true;
}

(:test)
function theFlipDirectionIgnoresLightsTheCallCannotReach(logger as Test.Logger) as Boolean {
    // A group is outside the scope this call commands — the floor target expands
    // to its members server-side and no override here touches the group itself —
    // so an on group must not decide the direction for the lights that are
    // commanded. Every commandable light here is off, so the floor turns on.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(:lights, {
        "lights" => {
            "light.off" => { "state" => false, "area_id" => "area.x", "available" => true },
            "light.grp" => { "state" => true, "area_id" => "area.x", "available" => true,
                "memberIds" => ["light.off"] }
        }
    }, null);

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorServices[0], "turn_on");
    return true;
}

(:test)
function toggleFloorLightsWithNoCommandableMembersQueuesNothing(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);

    // No lights section at all: the floor has no commandable members, so the
    // empty scope must not reach the client as an empty-target request.
    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorIds.size(), 0);
    return true;
}

(:test)
function aSecondFloorTapIsIgnoredWhileAMemberIsAlreadyPending(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(:lights, {
        "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } }
    }, null);

    coordinator.toggleFloorLights("floor.up");
    Test.assertEqual(client.toggledFloorIds.size(), 1);

    // light.a is still pending from the first floor action: a second tap
    // covering it must be ignored, regardless of what created the override.
    coordinator.toggleFloorLights("floor.up");
    Test.assertEqual(client.toggledFloorIds.size(), 1);

    // A lone entity tap on the same covered light is ignored too.
    coordinator.toggleEntity("light.a");
    Test.assertEqual(client.toggledEntityIds.size(), 0);
    return true;
}

(:test)
function stalenessGovernsTheFetchOnRevealNotNavigationShape(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    // Never refreshed: unconditionally stale, so a reveal fetches.
    client.setMsSinceLastRefresh(null);
    coordinator.onViewShown({});
    Test.assertEqual(client.refreshCount, 1);

    // Freshly completed: a reveal right after must not fetch again, whether
    // it arrived by push or by reveal — staleness alone decides.
    client.setMsSinceLastRefresh(0);
    coordinator.onViewShown({});
    Test.assertEqual(client.refreshCount, 1);
    return true;
}
