import Toybox.Lang;

// How the refresh that just settled turned out, as the one value the navigation
// gate reads.
class RefreshResult {
    // The first error the refresh met, kept for the whole refresh rather than
    // replaced by each reply: a later target succeeding must not make a refresh
    // that lost a part look clean by the time it settles.
    var error as RequestError or Null;

    // Whether any refresh has settled with every target intact. Nothing found
    // and nothing lost is still loading until this is true.
    var hasEverCompleted as Boolean;

    function initialize(error as RequestError or Null, hasEverCompleted as Boolean) {
        self.error = error;
        self.hasEverCompleted = hasEverCompleted;
    }
}
