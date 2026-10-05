import Toybox.Lang;
import Toybox.Test;

(:test)
class FiredLog {
    public var fired as Array<String> = [];

    function onFirst() as Void {
        fired.add("first");
    }

    function onSecond() as Void {
        fired.add("second");
    }
}

(:test)
function theEarliestActionFiresFirstWhateverOrderItWasScheduledIn(logger as Test.Logger) as Boolean {
    var timer = new FakeScheduler();
    var scheduler = new MultiplexScheduler(timer);
    var log = new FiredLog();

    scheduler.schedule(log.method(:onSecond), 200);
    scheduler.schedule(log.method(:onFirst), 100);
    timer.runScheduled();

    Test.assertEqual(log.fired.size(), 1);
    Test.assertEqual(log.fired[0], "first");

    timer.runScheduled();

    Test.assertEqual(log.fired.size(), 2);
    Test.assertEqual(log.fired[1], "second");
    return true;
}

(:test)
function actionsDueTogetherFireTogether(logger as Test.Logger) as Boolean {
    var timer = new FakeScheduler();
    var scheduler = new MultiplexScheduler(timer);
    var log = new FiredLog();

    scheduler.schedule(log.method(:onFirst), 100);
    scheduler.schedule(log.method(:onSecond), 100);
    timer.runScheduled();

    Test.assertEqual(log.fired.size(), 2);
    return true;
}
