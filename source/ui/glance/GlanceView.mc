import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runs in the glance process (32 KB, no HaState): the phone link is read live
// here, while the all-lights line comes from the summary the full app cached.
(:glance)
class GlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        GlanceView.onUpdate(dc);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        var height = dc.getHeight();
        var lights = allLightsText();

        if (lights == null) {
            drawLine(dc, height / 2, phoneText());
            return;
        }

        drawLine(dc, height / 3, phoneText());
        drawLine(dc, 2 * height / 3, lights);
    }

    private function drawLine(dc as Graphics.Dc, y as Number, text as String) as Void {
        dc.drawText(0, y, Graphics.FONT_GLANCE, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function phoneText() as String {
        var id = System.getDeviceSettings().phoneConnected
            ? Rez.Strings.GlancePhoneConnected
            : Rez.Strings.GlancePhoneDisconnected;
        return WatchUi.loadResource(id) as String;
    }

    private function allLightsText() as String or Null {
        var state = GlanceSummary.readAllLights();
        if (state == null) {
            return null;
        }

        var id = state == GlanceSummary.ALL_LIGHTS_ON ? Rez.Strings.GlanceAllLightsOn
            : state == GlanceSummary.ALL_LIGHTS_SOME ? Rez.Strings.GlanceSomeLightsOn
            : Rez.Strings.GlanceAllLightsOff;
        return WatchUi.loadResource(id) as String;
    }
}
