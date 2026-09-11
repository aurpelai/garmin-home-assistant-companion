import Toybox.Lang;
import Toybox.Test;

(:test)
module VisibilityMenuBuilderTest {

    function stateOf() as HaState {
        var haState = new HaState();
        var structure = {
            "areas" => { "area.kitchen" => { "name" => "Kitchen" }, "area.hall" => { "name" => "Hall" },
                "area.bedroom" => { "name" => "Bedroom" }, "area.shed" => { "name" => "Shed" } },
            "floors" => {
                "floor.up" => { "name" => "Up", "order" => 1, "areas" => ["area.bedroom"] },
                "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen", "area.hall"] }
            }
        };
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        return haState;
    }

    function idsOf(rows as Array<VisibilityToggleRowModel>) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < rows.size(); index++) {
            ids.add(rows[index].id);
        }

        return ids;
    }
}

(:test)
function rowsRunFloorByFloorLikeTheCardLoopWithUnflooredAreasLast(logger as Test.Logger) as Boolean {
    var rows = VisibilityMenuBuilder.build(VisibilityMenuBuilderTest.stateOf());

    Test.assertEqual(VisibilityMenuBuilderTest.idsOf(rows).toString(),
        ["floor.ground", "area.hall", "area.kitchen", "floor.up", "area.bedroom", "area.shed"].toString());
    Test.assert(rows[0].isFloor && rows[0].subLabel == null);
    Test.assert(!rows[1].isFloor);
    Test.assertEqual(rows[1].subLabel as String, "Ground");
    Test.assertEqual(rows[4].subLabel as String, "Up");
    Test.assert(!rows[5].isFloor && rows[5].subLabel == null);
    return true;
}

(:test)
function rowsAreCheckedUnlessTheirOwnIdIsHidden(logger as Test.Logger) as Boolean {
    var haState = VisibilityMenuBuilderTest.stateOf();
    haState.setFloorHidden("floor.up", true);
    haState.setAreaHidden("area.hall", true);

    var rows = VisibilityMenuBuilder.build(haState);

    Test.assert(rows[0].isVisible);
    Test.assert(!rows[1].isVisible);
    Test.assert(rows[2].isVisible);
    Test.assert(!rows[3].isVisible);
    Test.assert(rows[4].isVisible);
    return true;
}
