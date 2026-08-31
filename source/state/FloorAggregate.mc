import Toybox.Lang;

class FloorAggregate {
    public var lightSummary as String or Null;
    public var averages as Dictionary<String, String>;

    function initialize(lightSummary as String or Null, averages as Dictionary<String, String>) {
        self.lightSummary = lightSummary;
        self.averages = averages;
    }
}
