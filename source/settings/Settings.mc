import Toybox.Application;
import Toybox.Lang;

// The user config only: the URL and token the user edits in Properties. The
// webhook registration the app derives from them lives in Webhook.
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
        while (url.length() > 0 && (url.substring(url.length() - 1, url.length()) as String).equals("/")) {
            url = url.substring(0, url.length() - 1) as String;
        }
        return url;
    }

}
