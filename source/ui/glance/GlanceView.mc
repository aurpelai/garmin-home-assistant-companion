import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:glance)
class GlanceView extends WatchUi.GlanceView {
    private const ICON_GAP = 8;

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
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var rows = statusRows();
        var height = dc.getHeight();
        var count = rows.size() + 1;

        drawTitle(dc, height / (count + 1));

        for (var index = 0; index < rows.size(); index++) {
            drawStatus(dc, (index + 2) * height / (count + 1), rows[index]);
        }
    }

    private function statusRows() as Array<StatusRow> {
        if (!System.getDeviceSettings().phoneConnected) {
            return [new StatusRow(Rez.Drawables.GlanceClose, Graphics.COLOR_RED,
                WatchUi.loadResource(Rez.Strings.GlancePhoneDisconnected) as String)];
        }

        var rows = [] as Array<StatusRow>;

        var lights = lightRow();
        if (lights != null) {
            rows.add(lights);
        }

        var climate = GlanceSummary.getClimate();
        if (climate != null) {
            rows.add(new StatusRow(Rez.Drawables.GlanceThermometer, Graphics.COLOR_WHITE, climate));
        }

        return rows;
    }

    private function lightRow() as StatusRow or Null {
        var token = GlanceSummary.getLights();
        if (token == null) {
            return null;
        }

        var icon = token.equals(GlanceSummary.SOME_ON)
            ? Rez.Drawables.GlanceLightsSome : Rez.Drawables.GlanceLightsAll;
        var tint = token.equals(GlanceSummary.ALL_OFF) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_YELLOW;
        var text = token.equals(GlanceSummary.ALL_ON) ? Rez.Strings.GlanceAllLightsOn
            : token.equals(GlanceSummary.SOME_ON) ? Rez.Strings.GlanceSomeLightsOn
            : Rez.Strings.GlanceAllLightsOff;

        return new StatusRow(icon, tint, WatchUi.loadResource(text) as String);
    }

    private function drawTitle(dc as Graphics.Dc, y as Number) as Void {
        dc.drawText(0, y, _titleFont, WatchUi.loadResource(Rez.Strings.AppName) as String,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawStatus(dc as Graphics.Dc, y as Number, row as StatusRow) as Void {
        var icon = WatchUi.loadResource(row.icon) as BitmapResource;
        dc.drawBitmap2(0, y - icon.getHeight() / 2, icon, { :tintColor => row.tint });
        dc.drawText(icon.getWidth() + ICON_GAP, y, _statusFont, row.text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
