import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function registerIfNeededRegistersWhenNoCachedWebhookId(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new MockHaClient();

    (Application.getApp() as HaControllerApp).registerIfNeeded();

    Test.assertEqual(client.registerCount, 1);
    return true;
}

(:test)
function registerIfNeededNoOpsWhenUrlUnchangedWithCachedId(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("existing-id");
    Settings.setRegisteredUrl(Settings.getBaseUrl());
    var client = new MockHaClient();

    (Application.getApp() as HaControllerApp).registerIfNeeded();

    Test.assertEqual(client.registerCount, 0);
    return true;
}

(:test)
function registerIfNeededReRegistersAfterUrlChange(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    Settings.setRegisteredUrl("https://old.example.com");
    var client = new MockHaClient();

    (Application.getApp() as HaControllerApp).registerIfNeeded();

    Test.assertEqual(client.registerCount, 1);
    Test.assert(Settings.getWebhookId() == null);
    return true;
}

(:test)
function registerIfNeededNoOpsOnTokenOnlyChange(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("existing-id");
    Settings.setRegisteredUrl(Settings.getBaseUrl());
    var client = new MockHaClient();

    // A token-only change never touches Storage's registeredUrl, so the gate
    // sees the same URL it cached and must not re-register.
    (Application.getApp() as HaControllerApp).registerIfNeeded();

    Test.assertEqual(client.registerCount, 0);
    return true;
}

