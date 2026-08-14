import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function resolveErrorMessageMapsAuthCodes(logger as Test.Logger) as Boolean {
    var app = (Application.getApp() as HaCompanionApp);
    Test.assertEqual(app.resolveErrorMessage(401), Rez.Strings.ErrAuth);
    Test.assertEqual(app.resolveErrorMessage(403), Rez.Strings.ErrAuth);
    return true;
}

(:test)
function resolveErrorMessageMapsNegativeCodesToNetwork(logger as Test.Logger) as Boolean {
    var app = (Application.getApp() as HaCompanionApp);
    Test.assertEqual(app.resolveErrorMessage(-1), Rez.Strings.ErrNetwork);
    return true;
}

(:test)
function resolveErrorMessageMapsOtherCodesToUnknown(logger as Test.Logger) as Boolean {
    var app = (Application.getApp() as HaCompanionApp);
    Test.assertEqual(app.resolveErrorMessage(500), Rez.Strings.ErrUnknown);
    return true;
}
