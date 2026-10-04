import Rez.Styles;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class LabelsCard extends Card {
    // Slug ids never contain a hyphen, so this collides with no area or floor id.
    static const LABELS_CARD_ID = "labels-card";

    private const ICON_GAP = 8;

    function initialize() {
        Card.initialize(LabelsCard.LABELS_CARD_ID, null,
            WatchUi.loadResource(Rez.Strings.LabelsCardTitle) as String, [] as Array<SensorReading>);
    }

    function drawContent(dc as Graphics.Dc) as Void {
        var icon = WatchUi.loadResource(Rez.Drawables.Label) as WatchUi.BitmapResource;
        var textWidth = dc.getTextWidthInPixels(name, TITLE_FONT);
        var textHeight = dc.getFontHeight(TITLE_FONT);
        var contentLeft = dc.getWidth() / 2 - (icon.getWidth() + ICON_GAP + textWidth) / 2;
        var centerY = dc.getHeight() / 2;

        Rendering.useAntiAlias(dc, true);
        dc.drawBitmap2(contentLeft, centerY - icon.getHeight() / 2, icon, {
            :tintColor => system_color_dark__text.color
        });

        dc.setColor(system_color_dark__text.color, system_color_dark__text.background);
        dc.drawText(contentLeft + icon.getWidth() + ICON_GAP, centerY - textHeight / 2,
            TITLE_FONT, name, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function onSelect(coordinator as Coordinator) as Void {
        coordinator.showLabelsMenu();
    }
}
