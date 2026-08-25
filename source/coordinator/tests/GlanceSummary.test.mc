import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function allLightsRoundTripsThroughStorage(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setLightState(GlanceSummary.ALL_LIGHTS_SOME);
    Test.assert(GlanceSummary.getLightState() == GlanceSummary.ALL_LIGHTS_SOME);

    Application.Storage.clearValues();
    return true;
}

(:test)
function writingAbsentClearsAnyStoredValue(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setLightState(GlanceSummary.ALL_LIGHTS_ON);
    GlanceSummary.setLightState(null);
    Test.assert(GlanceSummary.getLightState() == null);

    Application.Storage.clearValues();
    return true;
}
