import Toybox.Lang;
import Toybox.WatchUi;

class LabelsMenu extends EntityMenu {

    function initialize(coordinator as Coordinator, model as EntityMenuModel,
                        subLabelProvider as SubLabelProvider) {
        EntityMenu.initialize(coordinator, model,
            WatchUi.loadResource(Rez.Strings.NoEntitiesInArea) as String, subLabelProvider);
    }

    function hasPerished(haState as HaState) as Boolean {
        return !haState.hasWatchedEntities();
    }

    function rebuild(haState as HaState) as Void {
        setModel(EntityMenuBuilder.build(
            WatchUi.loadResource(Rez.Strings.LabelsCardTitle) as String,
            haState.getWatchedToggleables(), haState.getWatchedSensors(), _subLabelProvider));
    }
}
