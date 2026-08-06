import Rez.Styles;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class GlanceView extends WatchUi.GlanceView {
    private var _app as HaControllerApp;
    private var _title as WatchUi.Text;
    private var _subtitle as WatchUi.Text;

    function initialize() {
        GlanceView.initialize();
        _app = Application.getApp() as HaControllerApp;

        var smallFont = Graphics.getVectorFont({
            :face => "RobotoCondensedBold",
            :size => 20
        }) as Graphics.VectorFont;

        var LargeFont = Graphics.getVectorFont({
            :face => "RobotoCondensedRegular",
            :size => 24
        }) as Graphics.VectorFont;

        _title = new WatchUi.Text({
            :text => "Home Assistant",
            :color => system_color_dark__text.color,
            :backgroundColor => system_color_dark__text.background,
            :font => smallFont,
            :locX => WatchUi.LAYOUT_HALIGN_START,
            :locY => 20
        });

        _subtitle = new WatchUi.Text({
            :text => "Garmin Watch Companion",
            :color => system_color_dark__text.color,
            :backgroundColor => system_color_dark__text.background,
            :font => LargeFont,
            :locX => WatchUi.LAYOUT_HALIGN_START,
            :locY => 45
        });
    }

    function onUpdate(dc) {
        _app.registerIfNeeded();
        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.clear();
        _title.draw(dc);
        _subtitle.draw(dc);
    }
}
