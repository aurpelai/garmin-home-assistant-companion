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
    private var _lastRefreshFailed as Boolean = false;

    function initialize() {
        HaClient.initialize();
    }

    function refresh(onTarget as Method) as Void {
        refreshCount++;
        _onTarget = onTarget;
        _lastRefreshFailed = false;
    }

    function lastRefreshFailed() as Boolean {
        return _lastRefreshFailed;
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

        if (error != null) {
            _lastRefreshFailed = true;
        } else {
            _hasCompletedARefresh = true;
        }

        (_onTarget as Method).invoke(target, result, true);
    }

    // Unlike fireTarget, this does not stamp completion on success — for the
    // one case that needs the distinction: a target landing before the whole
    // refresh has finished, which the real client does not treat as complete
    // either.
    function fireMidRefreshTarget(target as Symbol, result as Object or Null) as Void {
        _lastError = null;
        (_onTarget as Method).invoke(target, result, false);
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
    client.fireTarget(FetchTarget.LIGHTS, { "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } } }, null);
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
    client.fireTarget(FetchTarget.LIGHTS, {
        "lights" => {
            "light.a" => { "state" => false, "area_id" => "area.x" },
            "light.b" => { "state" => false, "area_id" => "area.x" }
        }
    }, null);

    // A tap only ever arrives from a screen the user is looking at.
    coordinator.onViewShown(new StubScreen(true));

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
        new RequestError(-1, RequestType.REQUEST));
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
    client.fireTarget(FetchTarget.LIGHTS, {
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
    client.fireTarget(FetchTarget.STRUCTURE, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(FetchTarget.LIGHTS, {
        "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } }
    }, null);

    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorIds.size(), 1);
    Test.assertEqual(client.toggledFloorIds[0], "floor.up");
    Test.assertEqual(client.toggledFloorServices[0], "turn_on");
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
    client.fireTarget(FetchTarget.STRUCTURE, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);
    client.fireTarget(FetchTarget.LIGHTS, {
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
    client.fireTarget(FetchTarget.STRUCTURE, {
        "floors" => { "floor.up" => { "name" => "Up", "order" => 0, "areas" => ["area.x"] } }
    }, null);

    // No lights section at all: the empty scope must not reach the client as an
    // empty-target request.
    coordinator.toggleFloorLights("floor.up");

    Test.assertEqual(client.toggledFloorIds.size(), 0);
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

    client.fireTarget(FetchTarget.LIGHTS, {
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

    client.fireTarget(FetchTarget.STRUCTURE, null, new RequestError(401, RequestType.REQUEST));

    // Nothing loaded and a spent threshold: the failure itself is the screen,
    // and the info screen is not a Screen to push into.
    Test.assert(coordinator.currentView() == null);
    return true;
}

(:test)
function aSuccessWithNoAreasAndNoErrorLeavesTheLoadingScreenUp(logger as Test.Logger) as Boolean {
    // A target can succeed without ever reporting an area — the very first
    // reply of a refresh, before the structure target has landed. Nothing
    // failed and nothing was found yet, so this is still loading rather than
    // a finding to report.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var loading = new StubScreen(true);

    coordinator.onViewShown(loading);
    client.fireMidRefreshTarget(FetchTarget.SENSORS, { "sensors" => {} });

    // The reply reaches the screen, so partial data is visible while the rest
    // is still in flight — but where the user belongs is not decided until the
    // refresh settles, so the loading screen keeps the display.
    Test.assert(coordinator.currentView() == loading);
    Test.assertEqual(loading.rebuildCount, 1);
    return true;
}

(:test)
function aCompletedRefreshWithNoAreasIsAFindingNotLoading(logger as Test.Logger) as Boolean {
    // The same empty structure, but a refresh has genuinely finished. A
    // healthy instance with nothing supported is told that plainly, rather
    // than being shown a spinner that will never resolve or an error it did
    // not cause.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var loading = new StubScreen(true);

    coordinator.onViewShown(loading);
    client.fireTarget(FetchTarget.STRUCTURE, { "areas" => {} }, null);

    Test.assert(coordinator.currentView() == null);
    return true;
}

(:test)
function anAreaWithNoErrorGoesToTheRealViewRatherThanTheInfoScreen(logger as Test.Logger) as Boolean {
    // The ordinary case: something to show and nothing wrong with it. No info
    // screen — the live view simply rebuilds with the data.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var view = new StubScreen(true);

    coordinator.onViewShown(view);
    client.fireTarget(FetchTarget.STRUCTURE, {
        "areas" => { "area.x" => { "name" => "Kitchen" } }
    }, null);

    Test.assert(coordinator.currentView() == view);
    Test.assertEqual(view.rebuildCount, 1);
    return true;
}

(:test)
function aStructureFailureStaysOnTheInfoScreenEvenAfterASiblingTargetLands(
        logger as Test.Logger) as Boolean {
    // The card loop builds from areas, and areas arrive only on the structure
    // target. Lights landing afterwards is not something to show without it —
    // sending the user to an empty home screen would hide the very failure
    // that explains why their home did not load.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);

    coordinator.onViewShown(new StubScreen(true));
    client.fireTarget(FetchTarget.STRUCTURE, null, new RequestError(401, RequestType.REQUEST));
    Test.assert(coordinator.currentView() == null);

    client.fireTarget(FetchTarget.LIGHTS, {
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.x" } }
    }, null);

    Test.assert(coordinator.currentView() == null);
    return true;
}

(:test)
function aFailedTargetKeepsDataOnScreenRatherThanReplacingItWithTheFailure(logger as Test.Logger) as Boolean {
    // A partial refresh: the structure landed, lights landed, sensors failed.
    // Replacing a populated screen with an error page would throw away what
    // the user can still use, so the view stays live and rebuilds rather than
    // being torn down for the info screen.
    //
    // Whether the failure also reaches the user as a toast is not asserted
    // here: ErrorMessage already pins what the toast would say, and observing
    // that WatchUi.showToast itself fired would mean
    // widening the coordinator's visibility for the test alone, which this
    // codebase does not do.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var view = new StubScreen(true);

    coordinator.onViewShown(view);
    client.fireTarget(FetchTarget.STRUCTURE, {
        "areas" => { "area.x" => { "name" => "Kitchen" } }
    }, null);
    client.fireTarget(FetchTarget.LIGHTS, {
        "lights" => { "light.a" => { "state" => true, "area_id" => "area.x" } }
    }, null);

    var rebuildsBeforeFailure = view.rebuildCount;
    client.fireTarget(FetchTarget.SENSORS, null, new RequestError(-1, RequestType.REQUEST));

    Test.assert(coordinator.currentView() == view);
    Test.assertEqual(view.rebuildCount, rebuildsBeforeFailure + 1);
    return true;
}

(:test)
function aFailedToggleDoesNotTakeTheScreenAway(logger as Test.Logger) as Boolean {
    // A service-call failure does not consult the grid: the override clears
    // either way, so the row visibly snaps back regardless of outcome. The
    // screen the user was on must survive that rather than being replaced by
    // the info screen.
    //
    // Whether a toast explains the snap-back is not asserted here, for the
    // same reason as the partial-refresh signal: ErrorMessage's own tests
    // pin the wording, and the coordinator has no accessor for "did I toast"
    // that exists for a production reason.
    var client = new FakeCoordinatorClient();
    var coordinator = new Coordinator(client);
    var view = new StubScreen(true);

    coordinator.onActivate();
    client.fireTarget(FetchTarget.LIGHTS, {
        "lights" => { "light.a" => { "state" => false, "area_id" => "area.x" } }
    }, null);
    coordinator.onViewShown(view);

    coordinator.toggleEntity("light.a");
    Test.assert(coordinator.haState().isPending("light.a"));

    client.fireToggleFailureAt(0, new RequestError(-1, RequestType.REQUEST));

    Test.assert(coordinator.currentView() == view);
    Test.assert(!coordinator.haState().isPending("light.a"));
    return true;
}
