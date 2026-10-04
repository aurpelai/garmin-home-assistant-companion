import Toybox.Lang;
import Toybox.WatchUi;

class AreaEntityMenu extends EntityMenu {
    private var _areaId as String;

    function initialize(coordinator as Coordinator, areaId as String, model as EntityMenuModel,
                        subLabelProvider as SubLabelProvider) {
        EntityMenu.initialize(coordinator, model,
            WatchUi.loadResource(Rez.Strings.NoEntitiesInArea) as String, subLabelProvider);
        _areaId = areaId;
    }

    function hasPerished(haState as HaState) as Boolean {
        return haState.getArea(_areaId) == null;
    }

    function rebuild(haState as HaState) as Void {
        var area = haState.getArea(_areaId);
        if (area == null) {
            return;
        }

        setModel(EntityMenuBuilder.build(area.name,
            haState.getToggleablesInArea(_areaId), haState.getSensorsInArea(_areaId), _subLabelProvider));
    }
}
