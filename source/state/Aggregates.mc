import Toybox.Lang;

// The precomputed means and light tallies Home Assistant hands back each fetch,
// keyed by place. Flat dictionaries keep the watch heap small; the per-place
// value objects are built only on demand.
class Aggregates {
    private var _lightCounts as Dictionary<String, LightCount>;
    private var _lightSummaries as Dictionary<String, String>;
    private var _homeLightSummary as String or Null;
    private var _areaAverages as Dictionary<String, Dictionary<String, String>>;
    private var _floorAverages as Dictionary<String, Dictionary<String, String>>;
    private var _homeAverages as Dictionary<String, String>;

    function initialize() {
        _lightCounts = {};
        _lightSummaries = {};
        _homeLightSummary = null;
        _areaAverages = {};
        _floorAverages = {};
        _homeAverages = {};
    }

    function setLights(counts as Dictionary<String, LightCount>,
                       summaries as Dictionary<String, String>,
                       home as String or Null) as Void {
        _lightCounts = counts;
        _lightSummaries = summaries;
        _homeLightSummary = home;
    }

    function setSensors(areaAverages as Dictionary<String, Dictionary<String, String>>,
                        floorAverages as Dictionary<String, Dictionary<String, String>>,
                        home as Dictionary<String, String>) as Void {
        _areaAverages = areaAverages;
        _floorAverages = floorAverages;
        _homeAverages = home;
    }

    function buildAreaAggregate(areaId as String) as AreaAggregate {
        var count = _lightCounts.get(areaId);

        return new AreaAggregate(
            count == null ? new LightCount(0, 0, 0) : count,
            resolveAverages(_areaAverages, areaId));
    }

    function buildFloorAggregate(floorId as String) as FloorAggregate {
        return new FloorAggregate(
            _lightSummaries.get(floorId),
            resolveAverages(_floorAverages, floorId));
    }

    function getHomeLightSummary() as String or Null {
        return _homeLightSummary;
    }

    function getHomeAverages() as Dictionary<String, String> {
        return _homeAverages;
    }

    private function resolveAverages(byId as Dictionary<String, Dictionary<String, String>>,
                                 id as String) as Dictionary<String, String> {
        var averages = byId.get(id);

        return averages == null ? ({} as Dictionary<String, String>) : averages;
    }
}
