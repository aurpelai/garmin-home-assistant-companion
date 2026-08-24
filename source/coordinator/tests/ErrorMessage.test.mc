import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

(:test)
function anAuthFailureReadsTheSameWhateverTheRequestType(logger as Test.Logger) as Boolean {
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
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.BAD_REQUEST, RequestType.REGISTRATION)),
        Rez.Strings.ErrRegistrationRejected);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.BAD_REQUEST, RequestType.REQUEST)),
        Rez.Strings.ErrTemplate);
    return true;
}

(:test)
function aNotFoundIsAnAddressProblemOnEitherRequestType(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.NOT_FOUND, RequestType.REGISTRATION)),
        Rez.Strings.ErrNotFound);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.NOT_FOUND, RequestType.REQUEST)),
        Rez.Strings.ErrNotFound);
    return true;
}

(:test)
function anUnusableWebhookReadsAsSetupFailure(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNUSABLE_WEBHOOK, RequestType.REQUEST)),
        Rez.Strings.ErrRegistrationFailed);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNUSABLE_WEBHOOK, RequestType.REGISTRATION)),
        Rez.Strings.ErrRegistrationFailed);
    return true;
}

(:test)
function aNegativeReasonMeansTheTransportFellOver(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(Communications.BLE_REQUEST_TOO_LARGE, RequestType.REQUEST)),
        Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function anUnreadableBodyIsItsOwnReasonNotACode(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNREADABLE_BODY, RequestType.REQUEST)),
        Rez.Strings.ErrUnreadableBody);
    return true;
}

