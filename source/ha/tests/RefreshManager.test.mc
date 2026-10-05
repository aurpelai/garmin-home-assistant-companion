import Toybox.Lang;
import Toybox.Test;

(:test)
class FakeRequests {
    public var latest as Dictionary<Symbol, FakeRequest> = {};
    public var count as Number = 0;

    function build(target as Symbol) as Method {
        var request = new FakeRequest();
        latest.put(target, request);
        count++;
        return request.method(:attempt);
    }

    function of(target as Symbol) as FakeRequest {
        return latest.get(target) as FakeRequest;
    }
}

(:test)
class SettleLog {
    public var targets as Array<Symbol> = [];
    public var settled as Array<Boolean> = [];

    function onTarget(target as Symbol, result as Object?, isSettled as Boolean) as Void {
        targets.add(target);
        settled.add(isSettled);
    }
}

(:test)
module RefreshManagerTest {
    function managerWith(requests as FakeRequests, log as SettleLog, scheduler as FakeScheduler) as RefreshManager {
        return new RefreshManager(requests.method(:build), log.method(:onTarget), scheduler);
    }

    function failEveryAttempt(request as FakeRequest, scheduler as FakeScheduler, reason as Number or Symbol) as Void {
        for (var i = 0; i < 4; i++) {
            request.settle(null, new RequestError(reason, null));
            scheduler.runScheduled();
        }
    }

    function settleAll(requests as FakeRequests) as Void {
        requests.of(FetchTarget.STRUCTURE).settle({}, null);
        requests.of(FetchTarget.LIGHTS).settle({}, null);
        requests.of(FetchTarget.FANS).settle({}, null);
        requests.of(FetchTarget.SENSORS).settle({}, null);
    }
}

(:test)
function aRefreshFiresEveryTargetAtOnce(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var manager = RefreshManagerTest.managerWith(requests, new SettleLog(), scheduler);

    manager.fetchAll();

    Test.assertEqual(requests.count, 4);
    Test.assertEqual(requests.of(FetchTarget.SENSORS).attempts, 1);
    Test.assert(manager.isFetching());
    return true;
}

(:test)
function aRefreshSettlesOnlyOnceEveryTargetHas(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var log = new SettleLog();
    var manager = RefreshManagerTest.managerWith(requests, log, scheduler);

    manager.fetchAll();
    RefreshManagerTest.settleAll(requests);

    Test.assertEqual(log.settled.size(), 4);
    Test.assert(!log.settled[2]);
    Test.assert(log.settled[3]);
    Test.assert(!manager.isFetching());
    return true;
}

(:test)
function onlyTheNewestRequestForATargetCounts(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var log = new SettleLog();
    var manager = RefreshManagerTest.managerWith(requests, log, scheduler);

    manager.fetch(FetchTarget.LIGHTS);
    var superseded = requests.of(FetchTarget.LIGHTS);
    manager.fetch(FetchTarget.LIGHTS);

    superseded.settle({}, null);

    Test.assertEqual(log.targets.size(), 0);
    Test.assert(manager.isFetching());

    requests.of(FetchTarget.LIGHTS).settle({}, null);

    Test.assertEqual(log.targets.size(), 1);
    Test.assert(log.settled[0]);
    return true;
}

(:test)
function anInvalidatedTargetStaysOutstandingUntilItsNextFetchSettles(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var log = new SettleLog();
    var manager = RefreshManagerTest.managerWith(requests, log, scheduler);

    manager.fetch(FetchTarget.FANS);
    var inFlight = requests.of(FetchTarget.FANS);
    manager.invalidate(FetchTarget.FANS);
    inFlight.settle({}, null);

    Test.assertEqual(log.targets.size(), 0);
    Test.assert(manager.isFetching());

    manager.fetch(FetchTarget.FANS);
    requests.of(FetchTarget.FANS).settle({}, null);

    Test.assert(log.settled[0]);
    return true;
}

(:test)
function everyFailureIsKeptInTargetOrder(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var manager = RefreshManagerTest.managerWith(requests, new SettleLog(), scheduler);

    manager.fetchAll();
    requests.of(FetchTarget.STRUCTURE).settle({}, null);
    RefreshManagerTest.failEveryAttempt(requests.of(FetchTarget.SENSORS), scheduler, -2);
    requests.of(FetchTarget.FANS).settle({}, null);
    RefreshManagerTest.failEveryAttempt(requests.of(FetchTarget.LIGHTS), scheduler, RequestError.TEMPLATE_ERROR);

    var errors = manager.getErrors();
    Test.assertEqual(errors.size(), 2);
    Test.assertEqual(errors[0].toDiagnosticCode(), "templateError (lights)");
    Test.assertEqual(errors[1].toDiagnosticCode(), "-2 (sensors)");
    return true;
}

(:test)
function aNewerRequestReplacesOnlyItsOwnTargetsFailure(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var manager = RefreshManagerTest.managerWith(requests, new SettleLog(), scheduler);

    manager.fetch(FetchTarget.FANS);
    manager.fetch(FetchTarget.SENSORS);

    RefreshManagerTest.failEveryAttempt(requests.of(FetchTarget.FANS), scheduler, -2);
    Test.assertEqual(manager.getErrors().size(), 1);

    manager.fetch(FetchTarget.FANS);

    Test.assertEqual(manager.getErrors().size(), 0);
    return true;
}

(:test)
function aFetchStartingFromIdleClearsEarlierFailures(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var scheduler = new FakeScheduler();
    var manager = RefreshManagerTest.managerWith(requests, new SettleLog(), scheduler);

    manager.fetch(FetchTarget.SENSORS);

    RefreshManagerTest.failEveryAttempt(requests.of(FetchTarget.SENSORS), scheduler, -2);
    Test.assertEqual(manager.getErrors().size(), 1);

    manager.fetch(FetchTarget.LIGHTS);

    Test.assertEqual(manager.getErrors().size(), 0);
    return true;
}
