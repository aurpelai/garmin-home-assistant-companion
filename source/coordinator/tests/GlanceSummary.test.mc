import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function lightsRoundTripThroughStorage(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setLights(LightSummary.SOME_ON);
    Test.assert((GlanceSummary.getLights() as String).equals(LightSummary.SOME_ON));

    Application.Storage.clearValues();
    return true;
}

(:test)
function writingAbsentClearsAnyStoredValue(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setLights(LightSummary.ALL_ON);
    GlanceSummary.setLights(null);
    Test.assert(GlanceSummary.getLights() == null);

    Application.Storage.clearValues();
    return true;
}

(:test)
function climateLineJoinsTemperatureAndHumidity(logger as Test.Logger) as Boolean {
    Test.assert((GlanceSummary.climateLine({ "temperature" => "21.6 °C", "humidity" => "52 %" }) as String).equals("21.6 °C • 52 %"));
    return true;
}

(:test)
function climateLineKeepsWhicheverIsPresent(logger as Test.Logger) as Boolean {
    Test.assert((GlanceSummary.climateLine({ "temperature" => "21.6 °C" }) as String).equals("21.6 °C"));
    Test.assert((GlanceSummary.climateLine({ "humidity" => "52 %" }) as String).equals("52 %"));
    Test.assert(GlanceSummary.climateLine({ "illuminance" => "5 lx" }) == null);
    Test.assert(GlanceSummary.climateLine({}) == null);
    return true;
}
