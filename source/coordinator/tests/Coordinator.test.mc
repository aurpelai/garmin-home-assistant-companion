import Toybox.Lang;
import Toybox.Test;

(:test)
function aLoadWhereEveryTargetSettlesCleanMarksTheHomeFullyLoaded(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    var scheduler = new TimerScheduler();
    var coordinator = new Coordinator(new HaClient(new FlowController(new WebRequestGateway(), scheduler), scheduler), haState,
        new TimerScheduler());

    coordinator.onTargetSettled(FetchTarget.STRUCTURE,
        { "areas" => { "area.room" => { "name" => "Room" } } }, false);
    Test.assert(!haState.isHomeFullyLoaded());

    coordinator.onTargetSettled(FetchTarget.FANS,
        { "fans" => { "fan.f" => { "state" => true, "area_id" => "area.room" } } }, true);
    Test.assert(haState.isHomeFullyLoaded());
    return true;
}
