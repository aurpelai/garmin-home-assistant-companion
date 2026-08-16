import Toybox.Lang;
import Toybox.Test;

(:test)
function anAuthFailureReadsTheSameWhateverTheRequestType(logger as Test.Logger) as Boolean {
    // The request type participates in the mapping, but not here: a rejected
    // token is a rejected token whichever request carried it.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(401, RequestType.REQUEST)), Rez.Strings.ErrAuth);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(403, RequestType.REQUEST)), Rez.Strings.ErrAuth);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(401, RequestType.REGISTRATION)), Rez.Strings.ErrAuth);
    return true;
}

(:test)
function aBadRequestReadsDifferentlyPerRequestType(logger as Test.Logger) as Boolean {
    // Why the value carries a request type at all: the same code accuses
    // different parties. On our own registration body it is our bug; on a fetch
    // the template failed on the Home Assistant side.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(400, RequestType.REGISTRATION)),
        Rez.Strings.ErrRegistrationRejected);
    Test.assertEqual(ErrorMessage.resolve(new RequestError(400, RequestType.REQUEST)), Rez.Strings.ErrTemplate);
    return true;
}

(:test)
function aNotFoundOnARegistrationMeansTheWebhookIdIsGone(logger as Test.Logger) as Boolean {
    Test.assertEqual(ErrorMessage.resolve(new RequestError(404, RequestType.REGISTRATION)),
        Rez.Strings.ErrRegistrationGone);
    return true;
}

(:test)
function aNegativeReasonMeansTheTransportFellOver(logger as Test.Logger) as Boolean {
    // Connect IQ's own failures are negative; an HTTP status never is.
    Test.assertEqual(ErrorMessage.resolve(new RequestError(-1, RequestType.REQUEST)), Rez.Strings.ErrNetwork);
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

