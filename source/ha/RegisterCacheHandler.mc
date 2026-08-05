import Toybox.Lang;

class RegisterCacheHandler {
    private var _callback as Method;

    function initialize(callback as Method) {
        _callback = callback;
    }

    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
        if (error == null) {
            Settings.setWebhookId(webhookId as String);
            Settings.setRegisteredUrl(Settings.getBaseUrl());
        }
        _callback.invoke(webhookId, error);
    }
}

