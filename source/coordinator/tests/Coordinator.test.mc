import Toybox.Lang;
import Toybox.Test;

// Records what the coordinator asked of the client. msSinceLastRefresh is
// settable because staleness is the one client fact the coordinator reads to
// decide anything.
(:test)
class FakeCoordinatorClient extends HaClient {
    public var refreshCount as Number = 0;
    public var cancelCount as Number = 0;
    public var discardCount as Number = 0;
    public var toggledFloorIds as Array<String> = [];
    public var toggledFloorServices as Array<String> = [];
    private var _msSinceLastRefresh as Number or Null = 0;

    function initialize() {
        HaClient.initialize();
    }

    function refresh(onTarget as Method) as Void {
        refreshCount++;
    }

    function queueFloorLights(floorId as String, service as String, callback as Method) as Void {
        toggledFloorIds.add(floorId);
        toggledFloorServices.add(service);
    }

    function cancelAll() as Void {
        cancelCount++;
    }

    function discardRegistration() as Void {
        discardCount++;
    }

    function msSinceLastRefresh() as Number or Null {
        return _msSinceLastRefresh;
    }

    function setMsSinceLastRefresh(value as Number or Null) as Void {
        _msSinceLastRefresh = value;
    }
}

(:test)
class StubScreen {

    function isObsolete(haState as HaState) as Boolean {
        return false;
    }

    function rebuild(haState as HaState) as Void {
    }
}

(:test)
module CoordinatorTest {

    function withFloorLights(coordinator as Coordinator, lights as Dictionary) as Void {
        var haState = coordinator.haState();
        haState.setAreas(HaPayload.parseAreas({ "areas" => { "area.x" => { "name" => "X" } } }));
        haState.setFloors(HaPayload.parseFloors({
            "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
        }));
        haState.setLights(HaPayload.parseLights({ "lights" => lights }));
    }

    function light(state as Boolean) as Dictionary {
        return { "state" => state, "area_id" => "area.x", "available" => true };
    }
}

(:test)
function aStaleHideDoesNotClearAViewAlreadyReplacedAsCurrent(logger as Test.Logger) as Boolean {
    var coordinator = new Coordinator(new FakeCoordinatorClient());
    var departing = new StubScreen();
    var arriving = new StubScreen();

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
function stalenessAloneDecidesWhetherARevealFetches(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    // Never refreshed reads as unconditionally stale rather than as fresh,
    // which is the difference between a first reveal fetching and hanging.
    client.setMsSinceLastRefresh(null);
    coordinator.onViewShown(new StubScreen());
    Test.assertEqual(client.refreshCount, 1);

    // A reveal right after a refresh must not fetch again, however the view
    // was reached — arriving is not itself a reason to refetch.
    client.setMsSinceLastRefresh(0);
    coordinator.onViewShown(new StubScreen());
    Test.assertEqual(client.refreshCount, 1);
    return true;
}

(:test)
function aConfigChangeThrowsAwayTheAnswersTheOldConfigProduced(logger as Test.Logger) as Boolean {
    // Home Assistant's visibility is per-user, so entities fetched under the
    // old token cannot be reconciled against the new one — the registration and
    // the state both go rather than being compared.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var discarded = coordinator.haState();

    coordinator.discardRegistration();

    Test.assertEqual(client.cancelCount, 1);
    Test.assertEqual(client.discardCount, 1);
    Test.assert(coordinator.haState() != discarded);
    return true;
}

(:test)
function aFloorTapCallsTheServiceItsOwnLightsImply(logger as Test.Logger) as Boolean {
    // The direction is the floor's, not one light's: anything still on means the
    // tap turns the floor off.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    CoordinatorTest.withFloorLights(coordinator, {
        "light.a" => CoordinatorTest.light(false),
        "light.b" => CoordinatorTest.light(true)
    });

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorIds[0], "floor.up");
    Test.assertEqual(client.toggledFloorServices[0], "turn_off");
    return true;
}

(:test)
function anAllOffFloorTapCallsTurnOn(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    CoordinatorTest.withFloorLights(coordinator, { "light.a" => CoordinatorTest.light(false) });

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorServices[0], "turn_on");
    return true;
}

(:test)
function aFloorWithNoLightsIsNotCalledAtAll(logger as Test.Logger) as Boolean {
    // An empty scope would reach Home Assistant as a service call naming no
    // entity, so the tap stops here rather than being sent and refused.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    CoordinatorTest.withFloorLights(coordinator, {});

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorIds.size(), 0);
    return true;
}
