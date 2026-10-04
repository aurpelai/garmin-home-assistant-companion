import Toybox.Graphics;
import Toybox.Lang;

class LabelsCard extends Card {
    // Slug ids never contain a hyphen, so this collides with no area or floor id.
    static const LABELS_CARD_ID = "labels-card";

    function initialize() {
        Card.initialize(LabelsCard.LABELS_CARD_ID, null, "", [] as Array<SensorReading>);
    }

    function drawContent(dc as Graphics.Dc) as Void {
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM, "Labels",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onSelect(coordinator as Coordinator) as Void {
        coordinator.showLabelsMenu();
    }
}
