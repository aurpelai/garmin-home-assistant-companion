import Toybox.Lang;
import Toybox.Test;

(:test)
function nothingLoadedAndNothingSettledIsStillLoading(logger as Test.Logger) as Boolean {
    // A cold start before any reply: empty because nothing has answered yet,
    // which is not the same as an answer that came back empty.
    Test.assertEqual(resolveDestination(false, null, false), :loading);
    return true;
}

(:test)
function anEmptyReplyThatCompletedIsAFindingNotLoading(logger as Test.Logger) as Boolean {
    // The completion fact is what separates these two cells: a refresh that
    // finished and returned nothing is a finding to report, and holding the
    // spinner would claim work is still in progress.
    Test.assertEqual(resolveDestination(false, null, true), :nothingFound);
    return true;
}

(:test)
function anErrorWithNothingLoadedIsTheOnlyThingToShow(logger as Test.Logger) as Boolean {
    // No data to keep on screen, so the failure itself becomes the screen —
    // both before any refresh completed and after one did.
    var error = new RequestError(-1, :fetch, :lights);

    Test.assertEqual(resolveDestination(false, error, false), :failure);
    Test.assertEqual(resolveDestination(false, error, true), :failure);
    return true;
}

(:test)
function entitiesOnScreenOutrankCompletionHistory(logger as Test.Logger) as Boolean {
    // The bottom row ignores whether a refresh ever completed: with data in
    // hand there is something to show either way.
    Test.assertEqual(resolveDestination(true, null, false), :realView);
    Test.assertEqual(resolveDestination(true, null, true), :realView);
    return true;
}

(:test)
function aPartialRefreshKeepsItsDataAndSignalsInstead(logger as Test.Logger) as Boolean {
    // Lights landed and sensors failed: such a refresh never stamps completion,
    // yet it must not replace a populated screen with an error page. The failure
    // reaches the user as a signal over the data instead.
    Test.assertEqual(resolveDestination(true, new RequestError(-1, :fetch, :sensors), false),
        :realViewSignalled);
    return true;
}
