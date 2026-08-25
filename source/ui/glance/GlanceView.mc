import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runs in the glance process (32 KB, no HaState): the phone link is read live
// here, while the all-lights line comes from the summary the full app cached.
(:glance)
class GlanceView extends WatchUi.GlanceView {
    private const ICON_GAP = 4;

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
        var lights = GlanceSummary.readAllLights();

        if (lights == null) {
            drawTitle(dc, height / 3);
            drawPhone(dc, 2 * height / 3);
            return;
        }

        drawTitle(dc, height / 4);
        drawPhone(dc, height / 2);
        drawLights(dc, 3 * height / 4, lights);
    }

    private function drawTitle(dc as Graphics.Dc, y as Number) as Void {
        dc.drawText(0, y, _titleFont, WatchUi.loadResource(Rez.Strings.AppName) as String,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawPhone(dc as Graphics.Dc, y as Number) as Void {
        var connected = System.getDeviceSettings().phoneConnected;
        var icon = connected ? Rez.Drawables.GlanceCheck : Rez.Drawables.GlanceClose;
        var tint = connected ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        var text = connected ? Rez.Strings.GlancePhoneConnected : Rez.Strings.GlancePhoneDisconnected;

        drawStatus(dc, y, WatchUi.loadResource(icon) as BitmapResource, tint,
            WatchUi.loadResource(text) as String);
    }

    private function drawLights(dc as Graphics.Dc, y as Number, state as GlanceSummary.AllLights) as Void {
        var filled = state != GlanceSummary.ALL_LIGHTS_SOME;
        var icon = filled ? Rez.Drawables.GlanceLightsAll : Rez.Drawables.GlanceLightsSome;
        var tint = state == GlanceSummary.ALL_LIGHTS_OFF ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_YELLOW;
        var text = state == GlanceSummary.ALL_LIGHTS_ON ? Rez.Strings.GlanceAllLightsOn
            : state == GlanceSummary.ALL_LIGHTS_SOME ? Rez.Strings.GlanceSomeLightsOn
            : Rez.Strings.GlanceAllLightsOff;

        drawStatus(dc, y, WatchUi.loadResource(icon) as BitmapResource, tint,
            WatchUi.loadResource(text) as String);
    }

    private function drawStatus(dc as Graphics.Dc, y as Number, icon as BitmapResource,
                                tint as Number, text as String) as Void {
        dc.drawBitmap2(0, y - icon.getHeight() / 2, icon, { :tintColor => tint });
        dc.drawText(icon.getWidth() + ICON_GAP, y, _statusFont, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
