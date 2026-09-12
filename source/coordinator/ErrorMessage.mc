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
            return Rez.Strings.ErrUnreadableBody;
        }

        if (reason == RequestError.UNUSABLE_WEBHOOK) {
            return Rez.Strings.ErrRegistrationFailed;
        }

        if (reason == HttpStatus.UNAUTHORIZED || reason == HttpStatus.FORBIDDEN) {
            return Rez.Strings.ErrAuth;
        }

        if (reason == HttpStatus.NOT_FOUND) {
            return Rez.Strings.ErrNotFound;
        }

        if (reason == HttpStatus.BAD_REQUEST) {
            return error.requestType == RequestType.REGISTRATION
                ? Rez.Strings.ErrRegistrationRejected
                : Rez.Strings.ErrTemplate;
        }

        if (reason == Communications.BLE_ERROR
                || reason == Communications.BLE_HOST_TIMEOUT
                || reason == Communications.BLE_SERVER_TIMEOUT
                || reason == Communications.BLE_NO_DATA
                || reason == Communications.BLE_CONNECTION_UNAVAILABLE
                || reason == Communications.REQUEST_CONNECTION_DROPPED) {
            return Rez.Strings.ErrNoPhone;
        }

        if (reason == Communications.BLE_QUEUE_FULL) {
            return Rez.Strings.ErrTooManyRequests;
        }

        if (reason == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return Rez.Strings.ErrTimeout;
        }

        if (reason == Communications.SECURE_CONNECTION_REQUIRED) {
            return Rez.Strings.ErrInsecureUrl;
        }

        if (reason == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
            return Rez.Strings.ErrBadResponse;
        }

        if (reason instanceof Number && reason < 0) {
            return Rez.Strings.ErrNetwork;
        }

        return Rez.Strings.ErrUnknown;
    }
}
