import Rez.Styles;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class GlanceView extends WatchUi.GlanceView {
    private var _app as HaControllerApp;

    private const FONT_SIZES = WatchUi.loadResource(Rez.JsonData.VectorFontSizes) as Dictionary;
    private var _titleFont as Graphics.VectorFont;
    private var _subtitleFont as Graphics.VectorFont;

    private var _title as WatchUi.Text;
    private var _subtitle as WatchUi.Text;

    function initialize() {
        GlanceView.initialize();
        _app = Application.getApp() as HaControllerApp;

        _titleFont = Graphics.getVectorFont({
            :face => ["RobotoCondensedBold", "RobotoRegular"],
            :size => FONT_SIZES.get("small") as Number
        }) as Graphics.VectorFont;

        _subtitleFont = Graphics.getVectorFont({
            :face => ["RobotoCondensedRegular", "RobotoRegular"],
            :size => FONT_SIZES.get("medium") as Number
        }) as Graphics.VectorFont;

        _title = new WatchUi.Text({});
        _subtitle = new WatchUi.Text({});
    }

    function onLayout(dc) {
        setLayout(Rez.Layouts.GlanceLayout(dc));

        _title = View.findDrawableById("title") as WatchUi.Text;
        _subtitle = View.findDrawableById("subtitle") as WatchUi.Text;

        _title.setText("Home Assistant");
        _title.setFont(_titleFont);
        _title.setBackgroundColor(system_color_dark__text.background);
        _title.setColor(system_color_dark__text.color);

        _subtitle.setText("Garmin Watch Companion");
        _subtitle.setFont(_subtitleFont);
        _subtitle.setBackgroundColor(system_color_dark__text.background);
        _subtitle.setColor(system_color_dark__text.color);
    }

    function onUpdate(dc) {
        _app.registerIfNeeded();

        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.clear();

        _title.draw(dc);
        _subtitle.draw(dc);
    }
}
