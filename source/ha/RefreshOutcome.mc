import Toybox.Lang;

// How the refresh that just settled turned out, as the one value the navigation
// gate reads. Separately these facts invite the wrong answer: `error` is the
// last reply's, so a refresh that lost its first target and recovered on its
// last looks clean, and `everCompleted` is about the session rather than this
// refresh.
class RefreshOutcome {
    // The last error any reply surfaced, refresh or service call alike, and null
    // once anything succeeds. What the user is shown when there is nothing to
    // show instead.
    var error as RequestError or Null;

    // Whether any target of the refresh just settled failed, which `error`
    // cannot answer: a later target succeeding clears it.
    var lostATarget as Boolean;

    // Whether any refresh has ever settled with every target intact. Nothing
    // found and nothing failed is still loading until this is true.
    var everCompleted as Boolean;

    function initialize(error as RequestError or Null, lostATarget as Boolean,
                        everCompleted as Boolean) {
        self.error = error;
        self.lostATarget = lostATarget;
        self.everCompleted = everCompleted;
    }
}
