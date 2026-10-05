import Toybox.Lang;
import Toybox.Test;

(:test)
function aSettledServiceCallReportsAndRefetchesOnlyItsOwnDomain(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var manager = RefreshManagerTest.managerWith(requests, new SettleLog(), new FakeScheduler());
    var succeeded = new ResultCapture();
    var failed = new ResultCapture();

    new ServiceCallHandler(succeeded.method(:onResult), manager, Domain.FAN).onSettled(true, null);
    new ServiceCallHandler(failed.method(:onResult), manager, Domain.FAN).onSettled(null, new RequestError(-2, null));

    Test.assertEqual(succeeded.result as Boolean, true);
    Test.assertEqual((failed.error as RequestError).reason as Number, -2);
    Test.assertEqual(requests.count, 2);
    Test.assert(requests.latest.hasKey(FetchTarget.FANS));
    Test.assertEqual(requests.latest.size(), 1);
    return true;
}

(:test)
function anInvalidatedTargetStaysUnsettledUntilItsRefetchSettles(logger as Test.Logger) as Boolean {
    var requests = new FakeRequests();
    var log = new SettleLog();
    var manager = RefreshManagerTest.managerWith(requests, log, new FakeScheduler());
    var handler = new ServiceCallHandler(new ResultCapture().method(:onResult), manager, Domain.LIGHT);

    handler.invalidateTarget();

    Test.assert(manager.isFetching());

    handler.onSettled(true, null);
    requests.of(FetchTarget.LIGHTS).settle({}, null);

    Test.assert(!manager.isFetching());
    Test.assert(log.refreshSettled[0]);
    return true;
}
