import Toybox.Lang;

// A failure that spent its retries, as the three facts a message needs. A value
// type, not a Model: nothing builds it for a consumer to read — it is the
// currency of the error path, constructed where a request was fired and passed
// along.
//
// The target is why this is a triple rather than a pair: the request type is
// :fetch for all three targets, so only the target can name which part is
// missing.
class RequestError {
    static const UNREADABLE_BODY = :unreadableBody;

    var reason as Object;
    var requestType as Symbol;
    var target as Symbol or Null;

    function initialize(reason as Object, requestType as Symbol, target as Symbol or Null) {
        self.reason = reason;
        self.requestType = requestType;
        self.target = target;
    }
}
