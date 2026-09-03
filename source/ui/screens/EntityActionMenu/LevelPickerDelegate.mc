import Toybox.Lang;
import Toybox.WatchUi;

class LevelPickerDelegate extends WatchUi.BehaviorDelegate {
    private var _coordinator as Coordinator;
    private var _picker as LevelPicker;

    function initialize(coordinator as Coordinator, picker as LevelPicker) {
        BehaviorDelegate.initialize();
        _coordinator = coordinator;
        _picker = picker;
    }

    function onPreviousPage() as Boolean {
        _picker.increase();
        return true;
    }

    function onNextPage() as Boolean {
        _picker.decrease();
        return true;
    }

    function onSelect() as Boolean {
        _coordinator.setAttribute(_picker.attribute, _picker.value());
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
