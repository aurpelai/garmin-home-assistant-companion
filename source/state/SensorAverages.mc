import Toybox.Lang;

// The precomputed means Home Assistant hands back each fetch, keyed by place.
// Flat dictionaries keep the watch heap small; a miss reads as empty.
class SensorAverages {
    private var _areaAverages as Dictionary<String, Dictionary<String, String>>;
    private var _floorAverages as Dictionary<String, Dictionary<String, String>>;

    function initialize() {
        _areaAverages = {};
        _floorAverages = {};
    }

    function set(areaAverages as Dictionary<String, Dictionary<String, String>>,
                 floorAverages as Dictionary<String, Dictionary<String, String>>) as Void {
        _areaAverages = areaAverages;
        _floorAverages = floorAverages;
    }

    function getArea(areaId as String) as Dictionary<String, String> {
        return resolve(_areaAverages, areaId);
    }

    function getFloor(floorId as String) as Dictionary<String, String> {
        return resolve(_floorAverages, floorId);
    }

    private function resolve(byId as Dictionary<String, Dictionary<String, String>>,
                             id as String) as Dictionary<String, String> {
        var averages = byId.get(id);

        return averages == null ? ({} as Dictionary<String, String>) : averages;
    }
}
