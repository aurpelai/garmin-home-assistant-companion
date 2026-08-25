import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function allLightsRoundTripsThroughStorage(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.writeAllLights(GlanceSummary.ALL_LIGHTS_SOME);
    Test.assert(GlanceSummary.readAllLights() == GlanceSummary.ALL_LIGHTS_SOME);

    Application.Storage.clearValues();
    return true;
}

(:test)
function writingAbsentClearsAnyStoredValue(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.writeAllLights(GlanceSummary.ALL_LIGHTS_ON);
    GlanceSummary.writeAllLights(null);
    Test.assert(GlanceSummary.readAllLights() == null);

    Application.Storage.clearValues();
    return true;
}
