import Toybox.Lang;

// How the refresh that just settled turned out, as the one value the navigation
// gate reads.
class RefreshResult {
    // The first failure the refresh met, kept for the whole refresh rather than
    // replaced by each reply: a later target succeeding must not make a refresh
    // that lost a part look clean by the time it settles.
    var failure as RequestError or Null;

    // Whether any refresh has settled with every target intact. Nothing found
    // and nothing lost is still loading until this is true.
    var hasCompleted as Boolean;

    function initialize(failure as RequestError or Null, hasCompleted as Boolean) {
        self.failure = failure;
        self.hasCompleted = hasCompleted;
    }
}
