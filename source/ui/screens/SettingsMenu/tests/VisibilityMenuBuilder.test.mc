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
                "floor.ground" => { "name" => "Ground", "order" => 0, "areas" => ["area.kitchen", "area.hall"] },
                "floor.empty" => { "name" => "Empty", "order" => 2, "areas" => [] }
            }
        };
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setFloors(HaPayload.parseFloors(structure));
        return haState;
    }

    function idsOf(rows as Array<VisibilityRowModel>) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < rows.size(); index++) {
            ids.add(rows[index].id);
        }

        return ids;
    }
}

(:test)
function rowsRunFloorByFloorLikeTheCardLoopSkippingAreaLessFloorsWithOtherLast(logger as Test.Logger) as Boolean {
    var rows = VisibilityMenuBuilder.build(VisibilityMenuBuilderTest.stateOf(), "Other");

    Test.assertEqual(VisibilityMenuBuilderTest.idsOf(rows).toString(),
        ["floor.ground", "area.hall", "area.kitchen", "floor.up", "area.bedroom",
            VisibilityStore.UNFLOORED_FLOOR_ID, "area.shed"].toString());
    Test.assertEqual((rows[0] as FloorVisibilityRowModel).areaCount, 2);
    Test.assertEqual((rows[3] as FloorVisibilityRowModel).areaCount, 1);
    Test.assertEqual((rows[5] as FloorVisibilityRowModel).name, "Other");
    Test.assert(rows[1] instanceof AreaVisibilityRowModel);
    Test.assert(rows[6] instanceof AreaVisibilityRowModel);
    return true;
}

(:test)
function rowsAreCheckedUnlessTheirOwnIdIsHidden(logger as Test.Logger) as Boolean {
    var haState = VisibilityMenuBuilderTest.stateOf();
    haState.setFloorHidden("floor.up", true);
    haState.setFloorHidden(VisibilityStore.UNFLOORED_FLOOR_ID, true);
    haState.setAreaHidden("area.hall", true);

    var rows = VisibilityMenuBuilder.build(haState, "Other");

    Test.assert(rows[0].isVisible);
    Test.assert(!rows[1].isVisible);
    Test.assert(rows[2].isVisible);
    Test.assert(!rows[3].isVisible);
    Test.assert(rows[4].isVisible);
    Test.assert(!rows[5].isVisible);
    Test.assert(rows[6].isVisible);
    return true;
}
