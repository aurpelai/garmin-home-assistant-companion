import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure transport-error-to-message mapping.

(:test)
function errorStringForMapsAuthCodes(logger as Test.Logger) as Boolean {
    var view = new LoadingView();
    Test.assertEqual(view.errorStringFor(401), Rez.Strings.ErrAuth);
    Test.assertEqual(view.errorStringFor(403), Rez.Strings.ErrAuth);
    return true;
}

(:test)
function errorStringForMapsNegativeCodesToNetwork(logger as Test.Logger) as Boolean {
    var view = new LoadingView();
    Test.assertEqual(view.errorStringFor(-1), Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function errorStringForMapsOtherCodesToUnknown(logger as Test.Logger) as Boolean {
    var view = new LoadingView();
    Test.assertEqual(view.errorStringFor(500), Rez.Strings.ErrUnknown);
    return true;
}
