import Toybox.Lang;

// One queued tap: the request to fire when its turn comes, and the caller's
// own callback to notify once it settles. A plain pair, not a Model — nothing
// builds it for a reader, HaClient constructs it inline to hold the two
// Methods a queued change needs.
class QueuedChange {
    var request as Method;
    var callback as Method;

    function initialize(request as Method, callback as Method) {
        self.request = request;
        self.callback = callback;
    }
}
