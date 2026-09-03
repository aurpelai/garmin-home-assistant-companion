import Toybox.Lang;
import Toybox.Test;

(:test)
function nextSnapsUpToTheStepAboveAnOffGridValue(logger as Test.Logger) as Boolean {
    var range = new LevelRange(0, 100, 10);

    Test.assertEqual(range.next(7), 10);
    Test.assertEqual(range.next(20), 30);
    return true;
}

(:test)
function previousSnapsDownToTheStepBelowAnOffGridValue(logger as Test.Logger) as Boolean {
    var range = new LevelRange(0, 100, 10);

    Test.assertEqual(range.previous(23), 20);
    Test.assertEqual(range.previous(20), 10);
    return true;
}

(:test)
function steppingWrapsAroundAtEitherEnd(logger as Test.Logger) as Boolean {
    var range = new LevelRange(0, 100, 10);

    Test.assertEqual(range.next(100), 0);
    Test.assertEqual(range.previous(0), 100);
    return true;
}

(:test)
function steppingHonoursANonZeroMinimum(logger as Test.Logger) as Boolean {
    var range = new LevelRange(2000, 4000, 500);

    Test.assertEqual(range.previous(2000), 4000);
    Test.assertEqual(range.next(4000), 2000);
    Test.assertEqual(range.next(2200), 2500);
    return true;
}

(:test)
function snapReturnsTheNearestStepWithinBounds(logger as Test.Logger) as Boolean {
    var range = new LevelRange(0, 100, 10);

    Test.assertEqual(range.snap(-20), 0);
    Test.assertEqual(range.snap(140), 100);
    Test.assertEqual(range.snap(47), 50);
    return true;
}
