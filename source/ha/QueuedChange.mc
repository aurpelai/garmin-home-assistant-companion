import Toybox.Lang;

class QueuedChange {
    var request as Method;
    var callback as Method;

    function initialize(request as Method, callback as Method) {
        self.request = request;
        self.callback = callback;
    }
}
