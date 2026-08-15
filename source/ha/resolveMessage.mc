import Toybox.Communications;
import Toybox.Lang;

// The one place a failure becomes words. The request type participates because
// the same code means different things per type: a bad request against our
// registration body means our own body is malformed, while the same code on a
// fetch means a template error on the Home Assistant side.
//
// Which codes map to which message moves on hardware evidence; the three facts
// it reads do not.
function resolveMessage(error as RequestError) as ResourceId {
    var reason = error.reason;

    if (reason == RequestError.UNREADABLE_BODY) {
        return Rez.Strings.ErrUnreadableBody;
    }

    if (reason == 401 || reason == 403) {
        return Rez.Strings.ErrAuth;
    }

    if (reason == 404 && error.requestType == :registration) {
        return Rez.Strings.ErrRegistrationGone;
    }

    if (reason == 400) {
        return error.requestType == :registration
            ? Rez.Strings.ErrRegistrationRejected
            : Rez.Strings.ErrTemplate;
    }

    if (reason instanceof Number && reason < 0) {
        return Rez.Strings.ErrNetwork;
    }

    return Rez.Strings.ErrUnknown;
}
