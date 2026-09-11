import Toybox.Lang;
import Toybox.Test;

(:test)
module AreaVisibilityTest {
    const NONE = {} as Dictionary<String, Boolean>;

    function floor(areas as Array<String>) as FloorModel {
        return new FloorModel("f", "Floor", 0, areas);
    }
}

(:test)
function aFloorWithNothingHiddenShowsEveryArea(logger as Test.Logger) as Boolean {
    var visible = AreaVisibility.resolveVisibleAreaIds(
        AreaVisibilityTest.floor(["a", "b"]), AreaVisibilityTest.NONE, AreaVisibilityTest.NONE);

    Test.assertEqual(visible.toString(), ["a", "b"].toString());
    return true;
}

(:test)
function aHiddenAreaDropsFromItsFloor(logger as Test.Logger) as Boolean {
    var visible = AreaVisibility.resolveVisibleAreaIds(
        AreaVisibilityTest.floor(["a", "b"]), AreaVisibilityTest.NONE, { "a" => true });

    Test.assertEqual(visible.toString(), ["b"].toString());
    return true;
}

(:test)
function aHiddenFloorShowsNoAreasWhateverTheirOwnState(logger as Test.Logger) as Boolean {
    var visible = AreaVisibility.resolveVisibleAreaIds(
        AreaVisibilityTest.floor(["a", "b"]), { "f" => true }, AreaVisibilityTest.NONE);

    Test.assertEqual(visible.size(), 0);
    return true;
}

(:test)
function aFloorIsVisibleUntilItsLastAreaIsHidden(logger as Test.Logger) as Boolean {
    var floor = AreaVisibilityTest.floor(["a", "b"]);

    Test.assert(AreaVisibility.isFloorVisible(floor, AreaVisibilityTest.NONE, { "a" => true }));
    Test.assert(!AreaVisibility.isFloorVisible(floor, AreaVisibilityTest.NONE, { "a" => true, "b" => true }));
    Test.assert(!AreaVisibility.isFloorVisible(floor, { "f" => true }, AreaVisibilityTest.NONE));
    return true;
}
