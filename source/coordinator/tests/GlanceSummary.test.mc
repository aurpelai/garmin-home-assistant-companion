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
function climateStoresTemperatureAndHumiditySeparatelyAndIgnoresOtherClasses(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setClimate({ "temperature" => "21.6 °C", "humidity" => "52 %", "illuminance" => "5 lx" });

    Test.assert((GlanceSummary.getTemperature() as String).equals("21.6 °C"));
    Test.assert((GlanceSummary.getHumidity() as String).equals("52 %"));

    Application.Storage.clearValues();
    return true;
}

(:test)
function climateClearsWhicheverReadingIsNoLongerPresent(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setClimate({ "temperature" => "21.6 °C", "humidity" => "52 %" });
    GlanceSummary.setClimate({ "temperature" => "22.0 °C" });

    Test.assert((GlanceSummary.getTemperature() as String).equals("22.0 °C"));
    Test.assert(GlanceSummary.getHumidity() == null);

    Application.Storage.clearValues();
    return true;
}
