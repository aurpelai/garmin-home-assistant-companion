import Toybox.Lang;

// Where the app belongs, from three facts and no stored status value. The one
// gate: no predicate decides whether the user hears about a failure, only
// whether the retries ran out and whether there is data on screen.
//
// | HaState        | no error, none completed | no error, one completed | error          |
// | -------------- | ------------------------ | ----------------------- | -------------- |
// | empty          | :loading                 | :nothingFound           | :failure       |
// | has entities   | :realView                | :realView               | :realViewSignalled |
//
// The completion fact separates a cold start, which is genuinely loading, from
// a refresh that came back with nothing, which is a finding. The bottom row
// ignores it: with data on screen there is something to show either way, so a
// partial refresh lands there despite never stamping completion.
function resolveDestination(hasEntities as Boolean, lastError as RequestError or Null,
                            hasCompletedARefresh as Boolean) as Symbol {
    if (hasEntities) {
        return lastError == null ? :realView : :realViewSignalled;
    }

    if (lastError != null) {
        return :failure;
    }

    return hasCompletedARefresh ? :nothingFound : :loading;
}
