import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function registerIfNeededDiscardsTheWebhookIdAfterAUrlChange(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    Settings.setRegisteredUrl("https://old.example.com");

    (Application.getApp() as HaCompanionApp).registerIfNeeded();

    Test.assert(Settings.getWebhookId() == null);
    return true;
}

(:test)
function registerIfNeededKeepsTheWebhookIdWhenTheUrlIsUnchanged(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("existing-id");
    Settings.setRegisteredUrl(Settings.getBaseUrl());

    (Application.getApp() as HaCompanionApp).registerIfNeeded();

    Test.assertEqual(Settings.getWebhookId() as String, "existing-id");
    return true;
}

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
