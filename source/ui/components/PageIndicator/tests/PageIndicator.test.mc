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
function aCountDroppingToASingleCardHidesAVisibleIndicator(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(5);

    indicator.updateIndex(3);
    indicator.setPageCount(1, 0);

    Test.assert(!indicator.isVisible());

    return true;
}

(:test)
function aTwoPageCountBecomesVisibleOnceNavigated(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(2);

    indicator.updateIndex(1);

    Test.assert(indicator.isVisible());

    return true;
}

(:test)
function aSingleCardNeverReveals(logger as Test.Logger) as Boolean {
    var indicator = new PageIndicator(1);

    indicator.updateIndex(0);

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
