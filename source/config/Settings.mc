import Toybox.Application;
import Toybox.Lang;

// Thin accessor over Application.Properties for the two user-configured values
// (HA base URL + long-lived token). Both are entered via Garmin Connect Mobile.
module Settings {

    function getBaseUrl() as String {
        var v = Application.Properties.getValue("haBaseUrl") as String or Null;
        return (v == null) ? "" : trimTrailingSlash(v);
    }

    function getToken() as String {
        var v = Application.Properties.getValue("haToken") as String or Null;
        return (v == null) ? "" : v;
    }

    // True only when both URL and token are non-empty. UI routes to ErrorView
    // with ErrNoConfig otherwise.
    function isConfigured() as Boolean {
        return !getBaseUrl().equals("") && !getToken().equals("");
    }

    function trimTrailingSlash(s as String) as String {
        // substring is typed String? but returns null only for an out-of-range
        // index; the length guard keeps the range valid, so the cast is safe.
        while (s.length() > 0 && (s.substring(s.length() - 1, s.length()) as String).equals("/")) {
            s = s.substring(0, s.length() - 1) as String;
        }
        return s;
    }
}
