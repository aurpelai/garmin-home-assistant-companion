import Toybox.Application;
import Toybox.Lang;

// Thin accessor over Application.Properties for the two user-configured values
// (HA base URL + long-lived token). Both are entered via Garmin Connect Mobile.
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
}
