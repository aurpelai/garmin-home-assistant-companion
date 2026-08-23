import Toybox.Lang;

// How the refresh that just settled turned out, as the one value the navigation
// gate reads.
class RefreshOutcome {
    // The first failure the refresh met, kept for the whole refresh rather than
    // replaced by each reply: a later target succeeding must not make a refresh
    // that lost a part look clean by the time it settles.
    var failure as RequestError or Null;

    // Whether any refresh has ever settled with every target intact. Nothing
    // found and nothing lost is still loading until this is true.
    var everCompleted as Boolean;

    function initialize(failure as RequestError or Null, everCompleted as Boolean) {
        self.failure = failure;
        self.everCompleted = everCompleted;
    }
}
