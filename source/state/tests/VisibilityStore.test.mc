import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
function hiddenSetsRoundTripThroughStorageAndDefaultToEmpty(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    Test.assertEqual(VisibilityStore.getHiddenFloors().size(), 0);
    Test.assertEqual(VisibilityStore.getHiddenAreas().size(), 0);

    VisibilityStore.setHiddenFloors({ "floor.up" => true });
    VisibilityStore.setHiddenAreas({ "area.attic" => true, "area.shed" => true });

    Test.assert(VisibilityStore.getHiddenFloors().hasKey("floor.up"));
    Test.assertEqual(VisibilityStore.getHiddenAreas().size(), 2);

    Application.Storage.clearValues();
    return true;
}

(:test)
function visibleAreaIdsAreNullUntilStoredAndAnEmptyListStaysEmpty(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();

    Test.assert(VisibilityStore.getVisibleAreaIds() == null);

    VisibilityStore.setVisibleAreaIds([] as Array<String>);
    Test.assertEqual((VisibilityStore.getVisibleAreaIds() as Array<String>).size(), 0);

    VisibilityStore.setVisibleAreaIds(["area.a"] as Array<String>);
    Test.assertEqual((VisibilityStore.getVisibleAreaIds() as Array<String>)[0], "area.a");

    Application.Storage.clearValues();
    return true;
}
