import Toybox.Communications;
import Toybox.Lang;

module ErrorMessage {

    // A 400 means our own request was bad on either request type — an unparseable
    // body, or plaintext to a registration that expects encryption. A template that
    // fails to render comes back as a 200 carrying an error object, never as a 400
    // (verified from the Home Assistant core source on 2026-09-12). The fetch
    // branch below still shows the template message; the honest split is filed as
    // an issue.
    function resolve(error as RequestError) as ResourceId {
        var reason = error.reason;

        if (reason == RequestError.UNREADABLE_BODY) {
            return Rez.Strings.ErrorUnreadableBody;
        }

        if (reason == RequestError.UNUSABLE_WEBHOOK) {
            return Rez.Strings.ErrorRegistrationFailed;
        }

        if (reason == HttpStatus.UNAUTHORIZED || reason == HttpStatus.FORBIDDEN) {
            return Rez.Strings.ErrorAuth;
        }

        if (reason == HttpStatus.NOT_FOUND) {
            return Rez.Strings.ErrorNotFound;
        }

        if (reason == HttpStatus.BAD_REQUEST) {
            return error.requestType == RequestType.REGISTRATION
                ? Rez.Strings.ErrorRegistrationRejected
                : Rez.Strings.ErrorTemplate;
        }

        if (reason == Communications.BLE_ERROR
                || reason == Communications.BLE_HOST_TIMEOUT
                || reason == Communications.BLE_SERVER_TIMEOUT
                || reason == Communications.BLE_NO_DATA
                || reason == Communications.BLE_CONNECTION_UNAVAILABLE
                || reason == Communications.REQUEST_CONNECTION_DROPPED) {
            return Rez.Strings.ErrorNoPhone;
        }

        if (reason == Communications.BLE_QUEUE_FULL) {
            return Rez.Strings.ErrorTooManyRequests;
        }

        if (reason == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return Rez.Strings.ErrorTimeout;
        }

        if (reason == Communications.SECURE_CONNECTION_REQUIRED) {
            return Rez.Strings.ErrorInsecureUrl;
        }

        if (reason == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
            return Rez.Strings.ErrorBadResponse;
        }

        if (reason instanceof Number && reason < 0) {
            return Rez.Strings.ErrorNetwork;
        }

        return Rez.Strings.ErrorUnknown;
    }
}
