import Toybox.Lang;
import Toybox.Test;

(:test)
function allAvailableOnResolvesToAllOn(logger as Test.Logger) as Boolean {
    var summary = CardLoopBuilder.resolveLightSummary(new ToggleableCount(3, 3, 0));

    Test.assert((summary as String).equals(LightSummary.ALL_ON));
    return true;
}

(:test)
function noneOnResolvesToAllOff(logger as Test.Logger) as Boolean {
    var summary = CardLoopBuilder.resolveLightSummary(new ToggleableCount(0, 3, 1));

    Test.assert((summary as String).equals(LightSummary.ALL_OFF));
    return true;
}

(:test)
function someOnResolvesToSomeOn(logger as Test.Logger) as Boolean {
    var summary = CardLoopBuilder.resolveLightSummary(new ToggleableCount(1, 3, 0));

    Test.assert((summary as String).equals(LightSummary.SOME_ON));
    return true;
}

(:test)
function noAvailableLightsResolvesToNull(logger as Test.Logger) as Boolean {
    var summary = CardLoopBuilder.resolveLightSummary(new ToggleableCount(0, 0, 2));

    Test.assert(summary == null);
    return true;
}
