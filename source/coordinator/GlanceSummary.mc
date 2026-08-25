import Toybox.Application;
import Toybox.Lang;

// The glance and the background service are separate processes with no access to
// HaState, so storage is the only channel between them and the running app.
(:glance, :background)
module GlanceSummary {
    const LIGHTS_KEY = "glanceLights";
    const TEMPERATURE_KEY = "glanceTemperature";
    const HUMIDITY_KEY = "glanceHumidity";

    function setLightSummary(summary as String or Null) as Void {
        set(LIGHTS_KEY, summary);
    }

    function getLightSummary() as String or Null {
        return Application.Storage.getValue(LIGHTS_KEY) as String or Null;
    }

    function setTemperature(value as Object or Null) as Void {
        set(TEMPERATURE_KEY, value);
    }

    function setHumidity(value as Object or Null) as Void {
        set(HUMIDITY_KEY, value);
    }

    function getTemperature() as String or Null {
        return Application.Storage.getValue(TEMPERATURE_KEY) as String or Null;
    }

    function getHumidity() as String or Null {
        return Application.Storage.getValue(HUMIDITY_KEY) as String or Null;
    }

    function set(key as String, value as Object or Null) as Void {
        if (value instanceof String) {
            Application.Storage.setValue(key, value);
            return;
        }

        Application.Storage.deleteValue(key);
    }
}
