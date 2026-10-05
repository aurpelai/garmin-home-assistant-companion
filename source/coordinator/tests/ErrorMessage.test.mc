import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

(:test)
function anAuthFailureReadsTheSameWhateverTheRequest(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.UNAUTHORIZED, FetchTarget.STRUCTURE)),
        Rez.Strings.ErrorAuth);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.FORBIDDEN, FetchTarget.STRUCTURE)),
        Rez.Strings.ErrorAuth);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.UNAUTHORIZED, RequestType.REGISTRATION)),
        Rez.Strings.ErrorAuth);
    return true;
}

(:test)
function aBadRequestReadsAsOurOwnBugUnlessRegistrationRejectedIt(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.BAD_REQUEST, RequestType.REGISTRATION)),
        Rez.Strings.ErrorRegistrationRejected);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.BAD_REQUEST, FetchTarget.SENSORS)),
        Rez.Strings.ErrorUnknown);
    return true;
}

(:test)
function aFailedRenderReadsAsOurOwnBug(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.TEMPLATE_ERROR, FetchTarget.LIGHTS)),
        Rez.Strings.ErrorUnknown);
    return true;
}

(:test)
function aNotFoundIsAnAddressProblemOnEitherRequest(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.NOT_FOUND, RequestType.REGISTRATION)),
        Rez.Strings.ErrorNotFound);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(HttpStatus.NOT_FOUND, FetchTarget.STRUCTURE)),
        Rez.Strings.ErrorNotFound);
    return true;
}

(:test)
function anUnusableWebhookReadsAsSetupFailure(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNUSABLE_WEBHOOK, FetchTarget.STRUCTURE)),
        Rez.Strings.ErrorRegistrationFailed);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNUSABLE_WEBHOOK, RequestType.REGISTRATION)),
        Rez.Strings.ErrorRegistrationFailed);
    return true;
}

(:test)
function aNegativeReasonMeansTheTransportFellOver(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(Communications.BLE_REQUEST_TOO_LARGE, FetchTarget.STRUCTURE)),
        Rez.Strings.ErrorNetwork);
    return true;
}

(:test)
function anUnreadableBodyIsItsOwnReasonNotACode(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(RequestError.UNREADABLE_BODY, FetchTarget.STRUCTURE)),
        Rez.Strings.ErrorUnreadableBody);
    return true;
}

