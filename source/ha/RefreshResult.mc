import Toybox.Lang;

// How the refresh that just settled turned out, as the one value the navigation
// gate reads.
class RefreshResult {
    var error as RequestError or Null;

    var hasEverCompleted as Boolean;

    function initialize(error as RequestError or Null, hasEverCompleted as Boolean) {
        self.error = error;
        self.hasEverCompleted = hasEverCompleted;
    }
}
