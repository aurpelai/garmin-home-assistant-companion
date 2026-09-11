import Toybox.Lang;
import Toybox.Test;

(:test)
module VisibilityMenuBuilderTest {

    function stateOf() as HaState {
        var haState = new HaState();
        var structure = {
            "areas" => { "area.kitchen" => { "name" => "Kitchen" }, "area.hall" => { "name" => "Hall" } },
            "floors" => {
                "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen", "area.hall"] },
                "floor.up" => { "name" => "Up", "order" => 1, "areas" => [] }
            }
        };
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        return haState;
    }
}

(:test)
function floorRowsListEveryFloorCheckedUnlessHidden(logger as Test.Logger) as Boolean {
    var haState = VisibilityMenuBuilderTest.stateOf();
    haState.setFloorHidden("floor.up", true);

    var rows = VisibilityMenuBuilder.buildFloorToggleRows(haState);

    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[0].name, "Ground");
    Test.assert(rows[0].isVisible);
    Test.assertEqual(rows[1].id, "floor.up");
    Test.assert(!rows[1].isVisible);
    return true;
}

(:test)
function areaRowsListTheGivenAreasCheckedUnlessHidden(logger as Test.Logger) as Boolean {
    var haState = VisibilityMenuBuilderTest.stateOf();
    haState.setAreaHidden("area.hall", true);

    var rows = VisibilityMenuBuilder.buildAreaToggleRows(haState, haState.getAreasInFloor("floor.ground"));

    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[0].id, "area.kitchen");
    Test.assert(rows[0].isVisible);
    Test.assertEqual(rows[1].name, "Hall");
    Test.assert(!rows[1].isVisible);
    return true;
}

(:test)
function filterRowsExplainWhyAFloorIsAbsentAndAddOtherOnlyForUnflooredAreas(logger as Test.Logger) as Boolean {
    var haState = new HaState();
    var structure = {
        "areas" => { "area.kitchen" => { "name" => "Kitchen" }, "area.bedroom" => { "name" => "Bedroom" },
            "area.attic" => { "name" => "Attic" }, "area.shed" => { "name" => "Shed" } },
        "floors" => {
            "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen"] },
            "floor.up" => { "name" => "Up", "order" => 1, "areas" => ["area.bedroom"] },
            "floor.roof" => { "name" => "Roof", "order" => 2, "areas" => ["area.attic"] },
            "floor.empty" => { "name" => "Empty", "order" => 3, "areas" => [] }
        }
    };
    haState.setAreas(HaPayload.parseAreas(structure));
    haState.setFloors(HaPayload.parseFloors(structure));
    haState.setFloorHidden("floor.up", true);
    haState.setAreaHidden("area.attic", true);
    haState.setAreaHidden("area.shed", true);

    var rows = VisibilityMenuBuilder.buildAreaVisibilityRows(haState, "Other");

    Test.assertEqual(rows.size(), 5);
    Test.assert(rows[0].subLabelId == null);
    Test.assert(rows[1].subLabelId == Rez.Strings.SettingsFloorHidden);
    Test.assert(rows[2].subLabelId == Rez.Strings.SettingsAllAreasHidden);
    Test.assert(rows[3].subLabelId == null);
    Test.assertEqual(rows[4].id, AreaVisibilityMenu.OTHER_ROW_ID);
    Test.assertEqual(rows[4].name, "Other");
    Test.assert(rows[4].subLabelId == Rez.Strings.SettingsAllAreasHidden);

    haState.setAreaHidden("area.shed", false);
    Test.assert(VisibilityMenuBuilder.buildAreaVisibilityRows(haState, "Other")[4].subLabelId == null);
    return true;
}

(:test)
function filterRowsOmitOtherWhenEveryAreaHasAFloor(logger as Test.Logger) as Boolean {
    var rows = VisibilityMenuBuilder.buildAreaVisibilityRows(VisibilityMenuBuilderTest.stateOf(), "Other");

    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[1].id, "floor.up");
    return true;
}
