import Toybox.Lang;
import Toybox.WatchUi;

class EntityActionMenuDelegate extends WatchUi.ActionMenuDelegate {
    private var _coordinator as Coordinator;
    private var _attributes as Array<AdjustableAttribute>;

    function initialize(coordinator as Coordinator, attributes as Array<AdjustableAttribute>) {
        ActionMenuDelegate.initialize();
        _coordinator = coordinator;
        _attributes = attributes;
    }

    function onSelect(item as WatchUi.ActionMenuItem) as Void {
        var attribute = _attributes[item.getId() as Number];

        if (attribute.isToggle()) {
            _coordinator.toggleAttribute(attribute, !(attribute.currentOn == true));
            return;
        }

        var picker = new LevelPicker(attribute);
        WatchUi.pushView(picker, new LevelPickerDelegate(_coordinator, picker), WatchUi.SLIDE_UP);
    }
}
