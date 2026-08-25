import Toybox.Application;
import Toybox.Lang;

// The glance and the background service are separate processes with no access to
// HaState, so storage is the only channel between them and the running app.
(:glance, :background)
module GlanceSummary {
    const LIGHTS_KEY = "glanceLights";
    const CLIMATE_KEY = "glanceClimate";

    function setLights(token as String or Null) as Void {
        put(LIGHTS_KEY, token);
    }

    function getLights() as String or Null {
        return Application.Storage.getValue(LIGHTS_KEY) as String or Null;
    }

    function setClimate(line as String or Null) as Void {
        put(CLIMATE_KEY, line);
    }

    function getClimate() as String or Null {
        return Application.Storage.getValue(CLIMATE_KEY) as String or Null;
    }

    // The join is presentation, so it lives here rather than in the HA template
    // that computed the means.
    function climateLine(means as Dictionary) as String or Null {
        var temperature = means.get("temperature");
        var humidity = means.get("humidity");
        var line = temperature instanceof String ? temperature : null;

        if (humidity instanceof String) {
            line = line == null ? humidity : line + " ∙ " + humidity;
        }

        return line;
    }

    function put(key as String, value as String or Null) as Void {
        if (value == null) {
            Application.Storage.deleteValue(key);
            return;
        }

        Application.Storage.setValue(key, value);
    }
}
