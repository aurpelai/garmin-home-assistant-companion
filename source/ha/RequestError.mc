import Toybox.Lang;

// A failure that spent its retries. Registering is told apart from everything
// else because a rejection there accuses our own body, where the same code on a
// request means Home Assistant could not do what we asked.
class RequestError {
    static const UNREADABLE_BODY = :unreadableBody;
    static const UNUSABLE_WEBHOOK = :unusableWebhook;

    var reason as Object;
    var requestType as Symbol;

    function initialize(reason as Object, requestType as Symbol) {
        self.reason = reason;
        self.requestType = requestType;
    }

    // A short stable token for the error surface. Symbol reasons carry a
    // hand-written literal because Symbol.toString() is opaque in release
    // builds; a numeric reason is its own code.
    function toDiagnosticCode() as String {
        if (reason == UNREADABLE_BODY) {
            return "unreadableBody";
        }

        if (reason == UNUSABLE_WEBHOOK) {
            return "unusableWebhook";
        }

        return reason.toString();
    }
}
