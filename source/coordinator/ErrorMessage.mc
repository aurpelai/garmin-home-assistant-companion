import Toybox.Communications;
import Toybox.Lang;

module ErrorMessage {
    function resolveCommon(errors as Array<RequestError>) as ResourceId {
        var message = resolve(errors[0]);

        for (var i = 1; i < errors.size(); i++) {
            if (resolve(errors[i]) != message) {
                return Rez.Strings.ErrorUnknown;
            }
        }

        return message;
    }

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

        if (reason == HttpStatus.BAD_REQUEST && error.request == RequestType.REGISTRATION) {
            return Rez.Strings.ErrorRegistrationRejected;
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
