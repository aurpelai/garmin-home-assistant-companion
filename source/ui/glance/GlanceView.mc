import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runs in the glance process (32 KB, no HaState): the phone link is read live
// here, while the all-lights line comes from the summary the full app cached.
(:glance)
class GlanceView extends WatchUi.GlanceView {
    private var _titleFont as Graphics.VectorFont;
    private var _statusFont as Graphics.VectorFont;

    function initialize() {
        GlanceView.initialize();

        var sizes = WatchUi.loadResource(Rez.JsonData.VectorFontSizes) as Dictionary;
        _titleFont = Graphics.getVectorFont({
            :face => ["RobotoCondensedBold", "RobotoRegular"],
            :size => sizes.get("small") as Number
        }) as Graphics.VectorFont;
        _statusFont = Graphics.getVectorFont({
            :face => ["RobotoCondensedRegular", "RobotoRegular"],
            :size => sizes.get("medium") as Number
        }) as Graphics.VectorFont;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        GlanceView.onUpdate(dc);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        var height = dc.getHeight();
        var lights = allLightsText();
        var title = WatchUi.loadResource(Rez.Strings.AppName) as String;

        if (lights == null) {
            drawLine(dc, _titleFont, height / 3, title);
            drawLine(dc, _statusFont, 2 * height / 3, phoneText());
            return;
        }

        drawLine(dc, _titleFont, height / 4, title);
        drawLine(dc, _statusFont, height / 2, phoneText());
        drawLine(dc, _statusFont, 3 * height / 4, lights);
    }

    private function drawLine(dc as Graphics.Dc, font as Graphics.VectorFont, y as Number, text as String) as Void {
        dc.drawText(0, y, font, text,
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
