import Toybox.Application;
import Toybox.Lang;

// The glance and the background service are separate processes with no access to
// HaState, so storage is the only channel between them and the running app.
(:glance, :background)
module GlanceSummary {
    const LIGHTS_KEY = "glanceLights";
    const TEMPERATURE_KEY = "glanceTemperature";
    const HUMIDITY_KEY = "glanceHumidity";

    function setLights(token as String or Null) as Void {
        put(LIGHTS_KEY, token);
    }

    function getLights() as String or Null {
        return Application.Storage.getValue(LIGHTS_KEY) as String or Null;
    }

    function setClimate(averages as Dictionary) as Void {
        put(TEMPERATURE_KEY, averages.get("temperature"));
        put(HUMIDITY_KEY, averages.get("humidity"));
    }

    function getTemperature() as String or Null {
        return Application.Storage.getValue(TEMPERATURE_KEY) as String or Null;
    }

    function getHumidity() as String or Null {
        return Application.Storage.getValue(HUMIDITY_KEY) as String or Null;
    }

    function put(key as String, value as Object or Null) as Void {
        if (value instanceof String) {
            Application.Storage.setValue(key, value);
            return;
        }

        Application.Storage.deleteValue(key);
    }
}
