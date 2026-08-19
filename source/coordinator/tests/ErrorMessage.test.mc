import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

(:test)
function anAuthFailureReadsTheSameWhateverTheRequestType(logger as Test.Logger) as Boolean {
    // A rejected token is a rejected token whichever request carried it.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.UNAUTHORIZED, RequestType.REQUEST)),
        Rez.Strings.ErrAuth);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.FORBIDDEN, RequestType.REQUEST)),
        Rez.Strings.ErrAuth);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.UNAUTHORIZED, RequestType.REGISTRATION)),
        Rez.Strings.ErrAuth);
    return true;
}

(:test)
function aBadRequestReadsDifferentlyPerRequestType(logger as Test.Logger) as Boolean {
    // Why the value carries a request type at all: the same code accuses
    // different parties. On our own registration body it is our bug; on a fetch
    // the template failed on the Home Assistant side.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.BAD_REQUEST, RequestType.REGISTRATION)),
        Rez.Strings.ErrRegistrationRejected);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.BAD_REQUEST, RequestType.REQUEST)),
        Rez.Strings.ErrTemplate);
    return true;
}

(:test)
function aNotFoundIsAnAddressProblemOnEitherRequestType(logger as Test.Logger) as Boolean {
    // A real 404 says the address has nothing behind it, which is the user's
    // URL either way — nothing about it accuses the registration.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.NOT_FOUND, RequestType.REGISTRATION)),
        Rez.Strings.ErrNotFound);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.NOT_FOUND, RequestType.REQUEST)),
        Rez.Strings.ErrNotFound);
    return true;
}

(:test)
function anUnusableWebhookReadsAsSetupFailure(logger as Test.Logger) as Boolean {
    // Reaching this reason means the webhook could not be used and registering
    // again did not rescue it, which is a broken setup whoever asked.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNUSABLE_WEBHOOK, RequestType.REQUEST)),
        Rez.Strings.ErrRegistrationFailed);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNUSABLE_WEBHOOK, RequestType.REGISTRATION)),
        Rez.Strings.ErrRegistrationFailed);
    return true;
}

(:test)
function aNegativeReasonMeansTheTransportFellOver(logger as Test.Logger) as Boolean {
    // An unclassified negative falls to the generic transport message; the
    // specific negatives above it carry their own. Connect IQ's own failures are
    // negative, an HTTP status never is.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(Communications.BLE_REQUEST_TOO_LARGE, RequestType.REQUEST)),
        Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function anUnreadableBodyIsItsOwnReasonNotACode(logger as Test.Logger) as Boolean {
    // A body-level symbol, not a transport code: on a sideloaded build the
    // error surface is the only diagnostic channel, so it must say that the
    // reply arrived and could not be read.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNREADABLE_BODY, RequestType.REQUEST)),
        Rez.Strings.ErrUnreadableBody);
    return true;
}

