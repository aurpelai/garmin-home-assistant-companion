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

        var rows = statusRows(dc);
        var height = dc.getHeight();
        var count = rows.size() + 1;

        drawTitle(dc, height / (count + 1));

        for (var index = 0; index < rows.size(); index++) {
            var y = (index + 2) * height / (count + 1);
            var row = rows[index];
            if (row instanceof MultiStatusRow) {
                drawItems(dc, y, row.items);
            } else {
                drawItems(dc, y, [new StatusItem(row.icon, row.tint, row.text, 0)]);
            }
        }
    }

    private function statusRows(dc as Graphics.Dc) as Array<StatusRow or MultiStatusRow> {
        if (!System.getDeviceSettings().phoneConnected) {
            return [new StatusRow(Rez.Drawables.GlanceClose, Graphics.COLOR_RED,
                WatchUi.loadResource(Rez.Strings.GlancePhoneDisconnected) as String)];
        }

        var rows = [] as Array<StatusRow or MultiStatusRow>;

        var lights = lightRow();
        if (lights != null) {
            rows.add(lights);
        }

        var climate = climateRow(dc);
        if (climate != null) {
            rows.add(climate);
        }

        return rows;
    }

    private function lightRow() as StatusRow or Null {
        var token = GlanceSummary.getLights();
        if (token == null) {
            return null;
        }

        var icon = token.equals(LightSummary.SOME_ON)
            ? Rez.Drawables.GlanceLightsSome
            : Rez.Drawables.GlanceLightsAll;
        var tint = token.equals(LightSummary.ALL_OFF)
            ? Graphics.COLOR_LT_GRAY
            : Graphics.COLOR_YELLOW;
        var text = token.equals(LightSummary.ALL_ON)
            ? Rez.Strings.GlanceAllLightsOn
            : token.equals(LightSummary.SOME_ON)
                ? Rez.Strings.GlanceSomeLightsOn
                : Rez.Strings.GlanceAllLightsOff;

        return new StatusRow(icon, tint, WatchUi.loadResource(text) as String);
    }

    private function climateRow(dc as Graphics.Dc) as MultiStatusRow or Null {
        var temperature = GlanceSummary.getTemperature();
        var humidity = GlanceSummary.getHumidity();
        var items = [] as Array<StatusItem>;

        if (temperature != null) {
            items.add(new StatusItem(
                Rez.Drawables.GlanceThermometer,
                Graphics.COLOR_ORANGE,
                temperature,
                0
            ));
        }
        if (humidity != null) {
            items.add(new StatusItem(
                Rez.Drawables.GlanceHumidity,
                Graphics.COLOR_BLUE,
                humidity,
                (dc.getWidth() / 2).toNumber()
            ));
        }

        return items.size() == 0 ? null : new MultiStatusRow(items);
    }

    private function drawTitle(dc as Graphics.Dc, y as Number) as Void {
        dc.drawText(0, y, _titleFont, WatchUi.loadResource(Rez.Strings.AppName) as String,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawItems(dc as Graphics.Dc, y as Number, items as Array<StatusItem>) as Void {
        for (var index = 0; index < items.size(); index++) {
            var item = items[index];
            var icon = WatchUi.loadResource(item.icon) as BitmapResource;
            dc.drawBitmap2(item.x, y - icon.getHeight() / 2, icon, { :tintColor => item.tint });
            dc.drawText(item.x + icon.getWidth() + ICON_GAP, y, _statusFont, item.text,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
