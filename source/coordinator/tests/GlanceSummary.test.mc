import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function lightsRoundTripThroughStorage(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setLightSummary(LightSummary.SOME_ON);
    Test.assert((GlanceSummary.getLightSummary() as String).equals(LightSummary.SOME_ON));

    Application.Storage.clearValues();
    return true;
}

(:test)
function writingAbsentClearsAnyStoredValue(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setLightSummary(LightSummary.ALL_ON);
    GlanceSummary.setLightSummary(null);
    Test.assert(GlanceSummary.getLightSummary() == null);

    Application.Storage.clearValues();
    return true;
}

(:test)
function temperatureAndHumidityRoundTripSeparately(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setTemperature("21.6 °C");
    GlanceSummary.setHumidity("52 %");

    Test.assert((GlanceSummary.getTemperature() as String).equals("21.6 °C"));
    Test.assert((GlanceSummary.getHumidity() as String).equals("52 %"));

    Application.Storage.clearValues();
    return true;
}

(:test)
function anAbsentReadingClearsItsStoredValue(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    GlanceSummary.setHumidity("52 %");
    GlanceSummary.setHumidity(null);

    Test.assert(GlanceSummary.getHumidity() == null);

    Application.Storage.clearValues();
    return true;
}
