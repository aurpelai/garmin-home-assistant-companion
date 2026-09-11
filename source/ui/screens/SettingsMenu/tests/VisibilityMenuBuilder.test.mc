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

    var rows = VisibilityMenuBuilder.buildFloorRows(haState);

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

    var rows = VisibilityMenuBuilder.buildAreaRows(haState, haState.getAreasInFloor("floor.ground"));

    Test.assertEqual(rows.size(), 2);
    Test.assertEqual(rows[0].id, "area.kitchen");
    Test.assert(rows[0].isVisible);
    Test.assertEqual(rows[1].name, "Hall");
    Test.assert(!rows[1].isVisible);
    return true;
}
