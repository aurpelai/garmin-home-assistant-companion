import Toybox.Lang;
import Toybox.Test;

(:test)
function anAuthFailureReadsTheSameWhateverTheRequestType(logger as Test.Logger) as Boolean {
    // The request type participates in the mapping, but not here: a rejected
    // token is a rejected token whichever request carried it.
    Test.assertEqual(resolveMessage(new RequestError(401, :fetch)), Rez.Strings.ErrAuth);
    Test.assertEqual(resolveMessage(new RequestError(403, :serviceCall)), Rez.Strings.ErrAuth);
    Test.assertEqual(resolveMessage(new RequestError(401, :registration)), Rez.Strings.ErrAuth);
    return true;
}

(:test)
function aBadRequestReadsDifferentlyPerRequestType(logger as Test.Logger) as Boolean {
    // Why the value carries a request type at all: the same code accuses
    // different parties. On our own registration body it is our bug; on a fetch
    // the template failed on the Home Assistant side.
    Test.assertEqual(resolveMessage(new RequestError(400, :registration)),
        Rez.Strings.ErrRegistrationRejected);
    Test.assertEqual(resolveMessage(new RequestError(400, :fetch)), Rez.Strings.ErrTemplate);
    return true;
}

(:test)
function aNotFoundOnARegistrationMeansTheWebhookIdIsGone(logger as Test.Logger) as Boolean {
    Test.assertEqual(resolveMessage(new RequestError(404, :registration)),
        Rez.Strings.ErrRegistrationGone);
    return true;
}

(:test)
function aNegativeReasonMeansTheTransportFellOver(logger as Test.Logger) as Boolean {
    // Connect IQ's own failures are negative; an HTTP status never is.
    Test.assertEqual(resolveMessage(new RequestError(-1, :fetch)), Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function anUnreadableBodyIsItsOwnReasonNotACode(logger as Test.Logger) as Boolean {
    // A body-level symbol, not a transport code: on a sideloaded build the
    // error surface is the only diagnostic channel, so it must say that the
    // reply arrived and could not be read.
    Test.assertEqual(resolveMessage(new RequestError(RequestError.UNREADABLE_BODY, :fetch)),
        Rez.Strings.ErrUnreadableBody);
    return true;
}

