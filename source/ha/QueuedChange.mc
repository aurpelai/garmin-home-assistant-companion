import Toybox.Lang;

// Monkey C has no closures, so a queued tap needs an object to hold the request
// to fire and the callback to notify once it settles.
class QueuedChange {
    var request as Method;
    var callback as Method;

    function initialize(request as Method, callback as Method) {
        self.request = request;
        self.callback = callback;
    }
}
