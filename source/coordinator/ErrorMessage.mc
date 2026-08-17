import Toybox.Communications;
import Toybox.Lang;

module ErrorMessage {

    // The request type participates because the same code means different things
    // per type: a bad request against our registration body means our own body is
    // malformed, while the same code on a fetch means a template error on the Home
    // Assistant side.
    //
    // Which codes map to which message moves on hardware evidence; the three facts
    // it reads do not.
    function resolve(error as RequestError) as ResourceId {
        var reason = error.reason;

        if (reason == RequestError.UNREADABLE_BODY) {
            return Rez.Strings.ErrUnreadableBody;
        }

        if (reason == 401 || reason == 403) {
            return Rez.Strings.ErrAuth;
        }

        if (reason == RequestError.HTTP_NOT_FOUND && error.requestType == RequestType.REGISTRATION) {
            return Rez.Strings.ErrRegistrationGone;
        }

        if (reason == 400) {
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
