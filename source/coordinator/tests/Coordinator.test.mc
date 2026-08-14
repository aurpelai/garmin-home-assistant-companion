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
    private var _lastError as RequestError or Null = null;
    private var _hasCompletedARefresh as Boolean = false;

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

    function lastError() as RequestError or Null {
        return _lastError;
    }

    function hasCompletedARefresh() as Boolean {
        return _hasCompletedARefresh;
    }

    function setHasCompletedARefresh(value as Boolean) as Void {
        _hasCompletedARefresh = value;
    }

    // Mirrors the real client's own bookkeeping: a settled failure becomes the
    // last error and any success clears it, so a test drives the grid's facts
    // the way the client would rather than setting them behind its back.
    function fireTarget(target as Symbol, result as Object or Null, error as RequestError or Null) as Void {
        _lastError = error;

        if (error == null) {
            _hasCompletedARefresh = true;
        }

        (_onTarget as Method).invoke(target, result, error);
    }

    function fireToggleSuccessAt(index as Number) as Void {
        _lastError = null;
        _toggleCallbacks[index].invoke(true, null);
    }

    function fireToggleFailureAt(index as Number, error as RequestError) as Void {
        _lastError = error;
        _toggleCallbacks[index].invoke(null, error);
    }
}

// Stands in for a live view: the coordinator only ever asks a view to rebuild,
// so a stub recording that call is the whole surface it needs.
(:test)
class StubScreen {
    public var rebuildCount as Number = 0;
    private var _subjectSurvives as Boolean;

    function initialize(subjectSurvives as Boolean) {
        _subjectSurvives = subjectSurvives;
    }

    function rebuild(haState as HaState) as Boolean {
        rebuildCount++;
        return _subjectSurvives;
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
    var departing = new StubScreen(true);
    var arriving = new StubScreen(true);

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
    client.fireToggleFailureAt(client.toggledEntityIds.size() - 1,
        new RequestError(-1, :serviceCall, null));
    coordinator.toggleEntity("light.b");
    Test.assertEqual(client.toggledEntityIds.size(), 4);
    return true;
}

(:test)
function aGroupTapMovesItsMembersAndIsBlockedByOneOfThemBeingPending(logger as Test.Logger) as Boolean {
    // A group's scope reaches its members, so its tap flips the rows beneath it
    // as well as its own — and the one-in-flight-per-entity rule then applies to
    // that whole scope, whichever end of it the earlier tap came from.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:lights, {
        "lights" => {
            "light.grp" => { "state" => false, "area_id" => "area.x",
                "memberIds" => ["light.one", "light.two"] },
            "light.one" => { "state" => false, "area_id" => "area.x" },
            "light.two" => { "state" => false, "area_id" => "area.x" }
        }
    }, null);

    coordinator.toggleEntity("light.one");
    Test.assertEqual(client.toggledEntityIds.size(), 1);

    // The member is pending, so the group covering it is refused.
    coordinator.toggleEntity("light.grp");
    Test.assertEqual(client.toggledEntityIds.size(), 1);

    client.fireToggleSuccessAt(0);
    coordinator.toggleEntity("light.grp");
    Test.assertEqual(client.toggledEntityIds.size(), 2);

    // Every row the group stands for now shows the assumed value, its own
    // included, so the menu is not half-updated.
    Test.assert(coordinator.haState().isOn("light.grp"));
    Test.assert(coordinator.haState().isOn("light.one"));
    Test.assert(coordinator.haState().isOn("light.two"));

    // And the reverse direction: a member covered by the pending group is refused.
    coordinator.toggleEntity("light.two");
    Test.assertEqual(client.toggledEntityIds.size(), 2);
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
function everyLightInTheFloorDecidesTheFlipDirection(logger as Test.Logger) as Boolean {
    // Nothing in the floor is out of scope: Home Assistant expands the floor
    // server-side and accepts a call to a light it cannot currently reach, so a
    // group and a dead bulb both count. The group alone being on is enough to
    // send the floor off.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(:lights, {
        "lights" => {
            "light.off" => { "state" => false, "area_id" => "area.x", "available" => true },
            "light.dead" => { "state" => false, "area_id" => "area.x", "available" => false },
            "light.grp" => { "state" => true, "area_id" => "area.x", "available" => true,
                "memberIds" => ["light.off"] }
        }
    }, null);

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorServices[0], "turn_off");
    return true;
}

(:test)
function toggleFloorLightsWithNoLightsQueuesNothing(logger as Test.Logger) as Boolean {
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onActivate();
    client.fireTarget(:structure, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);

    // No lights section at all: the empty scope must not reach the client as an
    // empty-target request.
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
    coordinator.onViewShown(new StubScreen(true));
    Test.assertEqual(client.refreshCount, 1);

    // Freshly completed: a reveal right after must not fetch again, whether
    // it arrived by push or by reveal — staleness alone decides.
    client.setMsSinceLastRefresh(0);
    coordinator.onViewShown(new StubScreen(true));
    Test.assertEqual(client.refreshCount, 1);
    return true;
}

(:test)
function theInfoScreenLeavesNothingLiveToPushInto(logger as Test.Logger) as Boolean {
    // It shows no Home Assistant data, so it is not a Screen. Leaving the
    // departed view current would push into something the user cannot see and
    // navigate out from under the screen that replaced it.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var view = new StubScreen(true);

    coordinator.onViewShown(view);
    Test.assert(coordinator.currentView() == view);

    coordinator.showInfo(Rez.Strings.ErrNoConfig, null);

    Test.assert(coordinator.currentView() == null);

    client.fireTarget(:lights, {
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.x" } }
    }, null);
    Test.assertEqual(view.rebuildCount, 0);
    return true;
}

(:test)
function aFailedStartupFetchLeavesTheLoadingScreenRatherThanHoldingIt(logger as Test.Logger) as Boolean {
    // A bad token used to leave the spinner up forever: the reply returned
    // early on error, so nothing ever looked at the failure. The failing reply
    // must navigate, which the info screen taking over shows.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var loading = new StubScreen(true);

    coordinator.onViewShown(loading);
    Test.assert(coordinator.currentView() == loading);

    client.fireTarget(:structure, null, new RequestError(401, :fetch, :structure));

    // Nothing loaded and a spent threshold: the failure itself is the screen,
    // and the info screen is not a Screen to push into.
    Test.assert(coordinator.currentView() == null);
    return true;
}

(:test)
function aFailedTargetKeepsDataOnScreenRatherThanReplacingItWithTheFailure(logger as Test.Logger) as Boolean {
    // A partial refresh: lights landed, sensors failed. Replacing a populated
    // screen with an error page would throw away what the user can still use,
    // so the view stays live and the failure reaches them another way.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var view = new StubScreen(true);

    coordinator.onViewShown(view);
    client.fireTarget(:lights, {
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.x" } }
    }, null);

    var rebuildsBeforeFailure = view.rebuildCount;
    client.fireTarget(:sensors, null, new RequestError(-1, :fetch, :sensors));

    Test.assert(coordinator.currentView() == view);
    Test.assertEqual(view.rebuildCount, rebuildsBeforeFailure + 1);
    return true;
}

(:test)
function aFailedToggleReportsItselfWithoutTakingTheScreenAway(logger as Test.Logger) as Boolean {
    // A service-call failure does not consult the grid: it reports itself over
    // whatever is showing, because the override clears either way and the row
    // snapping back with no explanation reads as the app ignoring the tap.
    // The screen the user was on must survive it.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var view = new StubScreen(true);

    coordinator.onActivate();
    client.fireTarget(:lights, {
        "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } }
    }, null);
    coordinator.onViewShown(view);

    coordinator.toggleEntity("light.a");
    Test.assert(coordinator.haState().isPending("light.a"));

    client.fireToggleFailureAt(0, new RequestError(-1, :serviceCall, null));

    Test.assert(coordinator.currentView() == view);
    Test.assert(!coordinator.haState().isPending("light.a"));
    return true;
}
