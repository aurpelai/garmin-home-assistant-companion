import Toybox.Application;
import Toybox.Lang;

// Thin accessor over Application.Properties for the two user-configured values
// (HA base URL + long-lived token, both entered via Garmin Connect Mobile) and
// over Application.Storage for the webhook_id registration derives from them
// (and the URL it was registered against) — derived values, not user config,
// so they never belong in Properties.
module Settings {

    function getBaseUrl() as String {
        var value = Application.Properties.getValue("haBaseUrl") as String or Null;
        return (value == null) ? "" : trimTrailingSlash(value);
    }

    function getToken() as String {
        var value = Application.Properties.getValue("haToken") as String or Null;
        return (value == null) ? "" : value;
    }

    // True only when both URL and token are non-empty. UI routes to ErrorView
    // with ErrNoConfig otherwise.
    function isConfigured() as Boolean {
        return !getBaseUrl().equals("") && !getToken().equals("");
    }

    function trimTrailingSlash(url as String) as String {
        // substring is typed String? but returns null only for an out-of-range
        // index; the length guard keeps the range valid, so the cast is safe.
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

    // Settings-save gate (spec: registration trigger). Ordered: a base-URL
    // change retires the id cached for the old URL and re-registers against
    // the new one; else no cached id registers once; else no-op. A
    // token-only change (URL unchanged) never re-registers.
    function registerIfNeeded(client as HaClient, callback as Method) as Void {
        var baseUrl = getBaseUrl();
        var registeredUrl = getRegisteredUrl();

        if (registeredUrl != null && !(registeredUrl as String).equals(baseUrl)) {
            clearWebhookId();
        } else if (getWebhookId() != null) {
            return;
        }

        client.register(callback);
    }
}
