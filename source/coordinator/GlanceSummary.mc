import Toybox.Application;
import Toybox.Lang;

// The glance is a separate process with no access to HaState, so storage is
// the only channel: the full app writes what the glance draws, the glance reads.
(:glance)
module GlanceSummary {
    enum AllLights {
        ALL_LIGHTS_OFF = 0,
        ALL_LIGHTS_SOME = 1,
        ALL_LIGHTS_ON = 2,
    }

    const ALL_LIGHTS_KEY = "glanceAllLights";

    function setLightState(state as AllLights or Null) as Void {
        if (state == null) {
            Application.Storage.deleteValue(ALL_LIGHTS_KEY);
            return;
        }

        Application.Storage.setValue(ALL_LIGHTS_KEY, state);
    }

    function getLightState() as AllLights or Null {
        return Application.Storage.getValue(ALL_LIGHTS_KEY) as AllLights or Null;
    }
}
