import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

(:test)
class FakeGateway {
    public var responders as Array<Method> = [];

    function post(path as String, body as Dictionary, onResponse as Method) as Void {
        responders.add(onResponse);
    }

    function cancelAll() as Void {
    }

    function reply(index as Number, code as Number) as Void {
        responders[index].invoke(code, null);
    }
}

(:test)
class ResponseLog {
    public var codes as Array<Number> = [];

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        codes.add(code);
    }
}

(:test)
function anAttemptWithNoReplyTimesOutAndALateReplyIsDropped(logger as Test.Logger) as Boolean {
    var inner = new FakeGateway();
    var timer = new FakeScheduler();
    var flowController = new FlowController(inner, new MultiplexScheduler(timer));
    var log = new ResponseLog();

    flowController.post("/a", {}, log.method(:onResponse));
    timer.runScheduled();
    inner.reply(0, 200);

    Test.assertEqual(log.codes.size(), 1);
    Test.assertEqual(log.codes[0], Communications.NETWORK_REQUEST_TIMED_OUT);
    return true;
}

(:test)
function aRequestRefusedByAFullQueueIsResentWhenAnotherSettles(logger as Test.Logger) as Boolean {
    var inner = new FakeGateway();
    var flowController = new FlowController(inner, new MultiplexScheduler(new FakeScheduler()));
    var first = new ResponseLog();
    var second = new ResponseLog();

    flowController.post("/a", {}, first.method(:onResponse));
    flowController.post("/b", {}, second.method(:onResponse));
    inner.reply(1, Communications.BLE_QUEUE_FULL);

    Test.assertEqual(second.codes.size(), 0);
    Test.assertEqual(inner.responders.size(), 2);

    inner.reply(0, 200);

    Test.assertEqual(inner.responders.size(), 3);

    inner.reply(2, 200);

    Test.assertEqual(second.codes.size(), 1);
    Test.assertEqual(second.codes[0], 200);
    return true;
}

(:test)
function aRefusalWithNothingElseInFlightIsResentAfterAShortWait(logger as Test.Logger) as Boolean {
    var inner = new FakeGateway();
    var timer = new FakeScheduler();
    var flowController = new FlowController(inner, new MultiplexScheduler(timer));
    var log = new ResponseLog();

    flowController.post("/a", {}, log.method(:onResponse));
    inner.reply(0, Communications.BLE_QUEUE_FULL);
    timer.runScheduled();

    Test.assertEqual(inner.responders.size(), 2);
    Test.assertEqual(log.codes.size(), 0);
    return true;
}

(:test)
function aRefusalAfterCancelAllStillResendsAfterAShortWait(logger as Test.Logger) as Boolean {
    var inner = new FakeGateway();
    var timer = new FakeScheduler();
    var flowController = new FlowController(inner, new MultiplexScheduler(timer));
    var log = new ResponseLog();

    flowController.post("/a", {}, new ResponseLog().method(:onResponse));
    flowController.cancelAll();
    flowController.post("/b", {}, log.method(:onResponse));
    inner.reply(1, Communications.BLE_QUEUE_FULL);
    timer.runScheduled();

    Test.assertEqual(inner.responders.size(), 3);
    Test.assertEqual(log.codes.size(), 0);
    return true;
}
