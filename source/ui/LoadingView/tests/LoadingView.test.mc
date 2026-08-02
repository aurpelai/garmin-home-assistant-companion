import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure transport-error-to-message mapping.

(:test)
function resolveErrorMessageMapsAuthCodes(logger as Test.Logger) as Boolean {
    var view = new LoadingView();
    Test.assertEqual(view.resolveErrorMessage(401), Rez.Strings.ErrAuth);
    Test.assertEqual(view.resolveErrorMessage(403), Rez.Strings.ErrAuth);
    return true;
}

(:test)
function resolveErrorMessageMapsNegativeCodesToNetwork(logger as Test.Logger) as Boolean {
    var view = new LoadingView();
    Test.assertEqual(view.resolveErrorMessage(-1), Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function resolveErrorMessageMapsOtherCodesToUnknown(logger as Test.Logger) as Boolean {
    var view = new LoadingView();
    Test.assertEqual(view.resolveErrorMessage(500), Rez.Strings.ErrUnknown);
    return true;
}
