import Toybox.Lang;

// A failure that spent its retries. Registering is told apart from everything
// else because a rejection there accuses our own body, where the same code on a
// request means Home Assistant could not do what we asked.
class RequestError {
    static const UNREADABLE_BODY = :unreadableBody;

    var reason as Object;
    var requestType as Symbol;

    function initialize(reason as Object, requestType as Symbol) {
        self.reason = reason;
        self.requestType = requestType;
    }
}
