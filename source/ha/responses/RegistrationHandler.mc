import Toybox.Lang;

class RegistrationHandler {
    private var _callback as Method;

    function initialize(callback as Method) {
        _callback = callback;
    }

    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
        if (error == null) {
            Webhook.setId(webhookId as String);
        }
        _callback.invoke(webhookId, error);
    }
}

