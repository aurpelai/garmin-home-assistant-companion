import Toybox.Application;
import Toybox.Lang;

// The only channel between the full app and its glance: the glance runs as a
// separate process with no access to HaState, so the app reduces state to the
// few values the glance draws and leaves them in storage for it to read back.
(:glance)
module GlanceSummary {
    enum AllLights {
        ALL_LIGHTS_OFF = 0,
        ALL_LIGHTS_SOME = 1,
        ALL_LIGHTS_ON = 2,
    }

    const ALL_LIGHTS_KEY = "glanceAllLights";

    function writeAllLights(state as AllLights or Null) as Void {
        if (state == null) {
            Application.Storage.deleteValue(ALL_LIGHTS_KEY);
            return;
        }

        Application.Storage.setValue(ALL_LIGHTS_KEY, state);
    }

    function readAllLights() as AllLights or Null {
        return Application.Storage.getValue(ALL_LIGHTS_KEY) as AllLights or Null;
    }
}
