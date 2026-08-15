import Toybox.Lang;

// A failure that spent its retries. The request type participates because the
// same code means different things per type, which is what resolveMessage reads.
class RequestError {
    static const UNREADABLE_BODY = :unreadableBody;

    var reason as Object;
    var requestType as Symbol;

    function initialize(reason as Object, requestType as Symbol) {
        self.reason = reason;
        self.requestType = requestType;
    }
}
