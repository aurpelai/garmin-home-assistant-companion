import Toybox.Application;
import Toybox.Lang;

// User config (URL, token) lives in Properties; the webhook_id and the URL it
// was registered against are derived, so they live in Storage, not Properties.
module Settings {

    function getBaseUrl() as String {
        var value = Application.Properties.getValue("haBaseUrl") as String or Null;
        return (value == null)
            ? ""
            : trimTrailingSlash(value);
    }

    function getToken() as String {
        var value = Application.Properties.getValue("haToken") as String or Null;
        return (value == null)
            ? ""
            : value;
    }

    function isConfigured() as Boolean {
        return !getBaseUrl().equals("") && !getToken().equals("");
    }

    function trimTrailingSlash(url as String) as String {
        // substring is null only for an out-of-range index; the length guard
        // keeps the range valid, so the cast can't hit null.
        while (url.length() > 0 && (url.substring(url.length() - 1, url.length()) as String).equals("/")) {
            url = url.substring(0, url.length() - 1) as String;
        }
        return url;
    }

    function getWebhookId() as String or Null {
        return Application.Storage.getValue("webhookId") as String or Null;
    }

    function setWebhookId(webhookId as String) as Void {
        Application.Storage.setValue("webhookId", webhookId);
    }

    function clearWebhookId() as Void {
        Application.Storage.deleteValue("webhookId");
    }

    function getRegisteredUrl() as String or Null {
        return Application.Storage.getValue("registeredUrl") as String or Null;
    }

    function setRegisteredUrl(url as String) as Void {
        Application.Storage.setValue("registeredUrl", url);
    }

}
