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
function fewerThanMinPageIndicatorsNeverBecomesVisible(logger as Test.Logger) as Boolean {
    // MIN_PAGE_INDICATORS is 3, but it is a private constant so we can't reference it here.
    var indicator = new PageIndicator(2);
    Test.assert(!indicator.isVisible());
    return true;
}
