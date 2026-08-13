import Toybox.Lang;
import Toybox.Test;

(:test)
function aTriggerMakesTheIndicatorVisible(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(5);

    indicator.updateIndex(3);

    Test.assert(indicator.isVisible());

    return true;
}

(:test)
function aFreshTriggerWhileVisibleKeepsItVisible(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(5);

    indicator.updateIndex(3);
    indicator.updateIndex(3);

    Test.assert(indicator.isVisible());

    return true;
}

(:test)
function hidingClearsTheVisibleState(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(5);

    indicator.updateIndex(3);
    indicator.onParentViewHide();

    Test.assert(!indicator.isVisible());

    return true;
}

(:test)
function aCountFallingBelowTheMinimumHidesAVisibleIndicator(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(5);

    indicator.updateIndex(3);
    indicator.setPageCount(2, 1);

    Test.assert(!indicator.isVisible());

    return true;
}

(:test)
function aRisingCountAloneDoesNotRevealTheIndicator(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(2);

    indicator.setPageCount(5, 0);

    Test.assert(!indicator.isVisible());

    return true;
}
