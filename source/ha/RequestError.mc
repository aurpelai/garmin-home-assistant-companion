import Toybox.Lang;

class RequestError {
    static const UNREADABLE_BODY = :unreadableBody;
    static const UNUSABLE_WEBHOOK = :unusableWebhook;
    static const TEMPLATE_ERROR = :templateError;

    // Symbol.toString() is opaque in release builds ("symbol (659)", verified
    // with a release build in the simulator on 2026-10-05), so each symbol in a
    // diagnostic code carries a hand-written literal.
    private static const LITERALS = {
        UNREADABLE_BODY => "unreadableBody",
        UNUSABLE_WEBHOOK => "unusableWebhook",
        TEMPLATE_ERROR => "templateError",
        FetchTarget.STRUCTURE => "structure",
        FetchTarget.LIGHTS => "lights",
        FetchTarget.FANS => "fans",
        FetchTarget.SENSORS => "sensors",
        RequestType.REGISTRATION => "registration"
    };

    var reason as Number or Symbol;
    var request as Symbol or Null;

    function initialize(reason as Number or Symbol, request as Symbol or Null) {
        self.reason = reason;
        self.request = request;
    }

    function toDiagnosticCode() as String {
        var code = toLiteral(reason);
        var request = self.request;

        return request == null ? code : code + " (" + toLiteral(request) + ")";
    }

    private function toLiteral(value as Number or Symbol) as String {
        var literal = LITERALS.get(value);

        return literal != null ? literal as String : value.toString();
    }
}
