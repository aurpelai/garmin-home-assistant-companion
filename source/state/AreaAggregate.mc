import Toybox.Lang;

class AreaAggregate {
    public var lightCount as LightCount;
    public var averages as Dictionary<String, String>;

    function initialize(lightCount as LightCount, averages as Dictionary<String, String>) {
        self.lightCount = lightCount;
        self.averages = averages;
    }
}
