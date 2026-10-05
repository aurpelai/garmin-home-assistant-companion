import Toybox.Communications;
import Toybox.Lang;

class RequestAttempt {
    var path as String;
    var body as Dictionary;

    private var _flowController as FlowController;
    private var _onResponse as Method;
    private var _isSettled as Boolean;

    function initialize(flowController as FlowController, path as String, body as Dictionary, onResponse as Method) {
        self.path = path;
        self.body = body;
        _flowController = flowController;
        _onResponse = onResponse;
        _isSettled = false;
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (_isSettled) {
            return;
        }

        if (code == Communications.BLE_QUEUE_FULL) {
            _flowController.onQueueFull(self);
            return;
        }

        settle(code, data);
    }

    function onTimeout() as Void {
        if (!_isSettled) {
            settle(Communications.NETWORK_REQUEST_TIMED_OUT, null);
        }
    }

    function cancel() as Void {
        _isSettled = true;
    }

    private function settle(code as Number, data as Dictionary or String or Null) as Void {
        _isSettled = true;
        _flowController.onSettled(self);
        _onResponse.invoke(code, data);
    }
}
