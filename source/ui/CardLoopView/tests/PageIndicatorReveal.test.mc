import Toybox.Lang;
import Toybox.Test;

(:test)
function aTriggerMakesTheIndicatorVisible(logger as Test.Logger) as Boolean {
    var reveal = new PageIndicatorReveal();

    reveal.onTrigger(3);

    Test.assert(reveal.isVisible());

    return true;
}

(:test)
function aFreshTriggerWhileVisibleKeepsItVisible(logger as Test.Logger) as Boolean {
    var reveal = new PageIndicatorReveal();

    reveal.onTrigger(3);
    reveal.onTrigger(3);

    Test.assert(reveal.isVisible());

    return true;
}

(:test)
function retractingHidesTheIndicator(logger as Test.Logger) as Boolean {
    var reveal = new PageIndicatorReveal();

    reveal.onTrigger(3);
    reveal.onRetracted();

    Test.assert(!reveal.isVisible());

    return true;
}

(:test)
function fewerThanTwoPagesNeverBecomesVisible(logger as Test.Logger) as Boolean {
    var reveal = new PageIndicatorReveal();

    reveal.onTrigger(1);

    Test.assert(!reveal.isVisible());

    return true;
}
