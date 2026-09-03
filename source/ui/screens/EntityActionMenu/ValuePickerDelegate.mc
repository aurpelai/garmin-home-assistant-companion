import Toybox.Lang;
import Toybox.WatchUi;

class ValuePickerDelegate extends WatchUi.BehaviorDelegate {
    private var _coordinator as Coordinator;
    private var _picker as ValuePicker;

    function initialize(coordinator as Coordinator, picker as ValuePicker) {
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
        _coordinator.setAttribute(_picker.attribute, _picker.getValue());
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
