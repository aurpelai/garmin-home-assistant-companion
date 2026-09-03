import Toybox.Lang;
import Toybox.Test;

(:test)
function nextLandsOnTheRoundMultipleAboveTheValue(logger as Test.Logger) as Boolean {
    var range = new ValueRange(0, 100, 10);

    Test.assertEqual(range.next(7), 10);
    Test.assertEqual(range.next(20), 30);
    return true;
}

(:test)
function previousLandsOnTheRoundMultipleBelowTheValue(logger as Test.Logger) as Boolean {
    var range = new ValueRange(0, 100, 10);

    Test.assertEqual(range.previous(23), 20);
    Test.assertEqual(range.previous(20), 10);
    return true;
}

(:test)
function steppingStopsAtTheEndsWithoutWrapping(logger as Test.Logger) as Boolean {
    var range = new ValueRange(0, 100, 10);

    Test.assertEqual(range.next(100), 100);
    Test.assertEqual(range.previous(0), 0);
    return true;
}

(:test)
function theGridLandsOnRoundMultiplesRegardlessOfTheMinimum(logger as Test.Logger) as Boolean {
    var range = new ValueRange(2202, 6535, 250);

    Test.assertEqual(range.next(2202), 2250);
    Test.assertEqual(range.next(2250), 2500);
    Test.assertEqual(range.previous(2500), 2250);
    return true;
}

(:test)
function theFirstAndLastStepsClampToMinAndMax(logger as Test.Logger) as Boolean {
    var range = new ValueRange(2202, 6535, 250);

    Test.assertEqual(range.previous(2250), 2202);
    Test.assertEqual(range.next(6500), 6535);
    Test.assertEqual(range.previous(6535), 6500);
    return true;
}
