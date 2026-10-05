import Toybox.Lang;
import Toybox.Test;

(:test)
function aLoadWhereEveryTargetSettlesCleanMarksTheHomeFullyLoaded(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    var coordinator = new Coordinator(new HaClient(new WebRequestGateway(), new TimerScheduler()), haState,
        new TimerScheduler());

    coordinator.onFetchTarget(FetchTarget.STRUCTURE,
        { "areas" => { "area.room" => { "name" => "Room" } } }, false);
    Test.assert(!haState.isHomeFullyLoaded());

    coordinator.onFetchTarget(FetchTarget.FANS,
        { "fans" => { "fan.f" => { "state" => true, "area_id" => "area.room" } } }, true);
    Test.assert(haState.isHomeFullyLoaded());
    return true;
}
