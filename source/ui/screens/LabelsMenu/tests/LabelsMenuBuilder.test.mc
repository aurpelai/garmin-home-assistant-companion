import Toybox.Lang;
import Toybox.Test;

(:test)
module LabelsMenuBuilderTest {

    function stateOf(lights as Dictionary) as HaState {
        var haState = new HaState();
        var structure = {
            "areas" => { "area.den" => { "name" => "Den" }, "area.attic" => { "name" => "Attic" },
                "area.empty" => { "name" => "Empty" } }
        };
        haState.setAreas(HaPayload.parseAreas(structure));
        haState.setToggleables(Domain.LIGHT, HaPayload.parseLights({ "lights" => lights }));
        haState.setToggleables(Domain.FAN, {} as Dictionary<String, ToggleableModel>);
        haState.setSensors(HaPayload.parseSensors({ "sensors" => {} }));
        haState.setIncludedLabels({ "label.watched" => true });
        return haState;
    }

    function watchedLight(areaId as String or Null) as Dictionary {
        return { "state" => true, "area_id" => areaId, "available" => true, "labels" => ["label.watched"] };
    }

    function idsOf(model as EntityMenuModel) as Array<String> {
        var ids = [] as Array<String>;

        for (var index = 0; index < model.rows.size(); index++) {
            ids.add(model.rows[index].id);
        }

        return ids;
    }

    function build(haState as HaState) as EntityMenuModel {
        return LabelsMenuBuilder.build("Labels", haState, "Other", new FakeSubLabelProvider());
    }
}

(:test)
function rowsRunAreaByAreaSortedByNameWithAnAreaHeaderBeforeEach(logger as Test.Logger) as Boolean {
    var model = LabelsMenuBuilderTest.build(LabelsMenuBuilderTest.stateOf({
        "light.den" => LabelsMenuBuilderTest.watchedLight("area.den"),
        "light.attic" => LabelsMenuBuilderTest.watchedLight("area.attic")
    }));

    Test.assertEqual(LabelsMenuBuilderTest.idsOf(model).toString(),
        ["area.attic", "light.attic", "area.den", "light.den"].toString());
    return true;
}

(:test)
function arealessWatchedEntitiesTrailUnderTheOtherHeader(logger as Test.Logger) as Boolean {
    var model = LabelsMenuBuilderTest.build(LabelsMenuBuilderTest.stateOf({
        "light.den" => LabelsMenuBuilderTest.watchedLight("area.den"),
        "light.stray" => LabelsMenuBuilderTest.watchedLight(null)
    }));

    Test.assertEqual(LabelsMenuBuilderTest.idsOf(model).toString(),
        ["area.den", "light.den", LabelsMenuBuilder.AREALESS_ID, "light.stray"].toString());
    return true;
}

(:test)
function watchedEntitiesInAnUnknownAreaTrailUnderTheOtherHeader(logger as Test.Logger) as Boolean {
    var model = LabelsMenuBuilderTest.build(LabelsMenuBuilderTest.stateOf({
        "light.den" => LabelsMenuBuilderTest.watchedLight("area.den"),
        "light.ghost" => LabelsMenuBuilderTest.watchedLight("area.gone")
    }));

    Test.assertEqual(LabelsMenuBuilderTest.idsOf(model).toString(),
        ["area.den", "light.den", LabelsMenuBuilder.AREALESS_ID, "light.ghost"].toString());
    return true;
}

(:test)
function anAreaWithNoWatchedEntityEmitsNoHeader(logger as Test.Logger) as Boolean {
    var model = LabelsMenuBuilderTest.build(LabelsMenuBuilderTest.stateOf({
        "light.den" => LabelsMenuBuilderTest.watchedLight("area.den"),
        "light.unwatched" => { "state" => true, "area_id" => "area.attic", "available" => true }
    }));

    Test.assertEqual(LabelsMenuBuilderTest.idsOf(model).toString(),
        ["area.den", "light.den"].toString());
    return true;
}
