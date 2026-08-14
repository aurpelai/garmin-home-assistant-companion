import Toybox.Lang;
import Toybox.Test;

(:test)
function anAuthFailureReadsTheSameWhateverTheRequestType(logger as Test.Logger) as Boolean {
    // The request type participates in the mapping, but not here: a rejected
    // token is a rejected token whichever request carried it.
    Test.assertEqual(resolveMessage(new RequestError(401, :fetch, :lights)), Rez.Strings.ErrAuth);
    Test.assertEqual(resolveMessage(new RequestError(403, :serviceCall, null)), Rez.Strings.ErrAuth);
    Test.assertEqual(resolveMessage(new RequestError(401, :registration, null)), Rez.Strings.ErrAuth);
    return true;
}

(:test)
function aBadRequestReadsDifferentlyPerRequestType(logger as Test.Logger) as Boolean {
    // Why the value carries a request type at all: the same code accuses
    // different parties. On our own registration body it is our bug; on a fetch
    // the template failed on the Home Assistant side.
    Test.assertEqual(resolveMessage(new RequestError(400, :registration, null)),
        Rez.Strings.ErrRegistrationRejected);
    Test.assertEqual(resolveMessage(new RequestError(400, :fetch, :sensors)), Rez.Strings.ErrTemplate);
    return true;
}

(:test)
function aNotFoundOnARegistrationMeansTheWebhookIdIsGone(logger as Test.Logger) as Boolean {
    Test.assertEqual(resolveMessage(new RequestError(404, :registration, null)),
        Rez.Strings.ErrRegistrationGone);
    return true;
}

(:test)
function aNegativeReasonMeansTheTransportFellOver(logger as Test.Logger) as Boolean {
    // Connect IQ's own failures are negative; an HTTP status never is.
    Test.assertEqual(resolveMessage(new RequestError(-1, :fetch, :lights)), Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function anUnreadableBodyIsItsOwnReasonNotACode(logger as Test.Logger) as Boolean {
    // A body-level symbol, not a transport code: on a sideloaded build the
    // error surface is the only diagnostic channel, so it must say that the
    // reply arrived and could not be read.
    Test.assertEqual(resolveMessage(new RequestError(RequestError.UNREADABLE_BODY, :fetch, :structure)),
        Rez.Strings.ErrUnreadableBody);
    return true;
}

(:test)
function onlyAFetchNamesAMissingPart(logger as Test.Logger) as Boolean {
    // The request type is :fetch for all three targets, so the target is the
    // only thing that can say which part a partial refresh lost. A service call
    // and a registration have no target and name nothing.
    Test.assertEqual(resolveMissingPart(new RequestError(-1, :fetch, :lights)) as ResourceId,
        Rez.Strings.PartLights);
    Test.assertEqual(resolveMissingPart(new RequestError(-1, :fetch, :sensors)) as ResourceId,
        Rez.Strings.PartSensors);
    Test.assertEqual(resolveMissingPart(new RequestError(-1, :fetch, :structure)) as ResourceId,
        Rez.Strings.PartStructure);
    Test.assert(resolveMissingPart(new RequestError(-1, :serviceCall, null)) == null);
    Test.assert(resolveMissingPart(new RequestError(-1, :registration, null)) == null);
    return true;
}
