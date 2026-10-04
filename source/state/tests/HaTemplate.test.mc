import Toybox.Lang;
import Toybox.Test;

(:test)
function emptyHiddenSetsRenderUnfiltered(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.LIGHTS, {}, {}, [] as Array<String>);

    Test.assert(template.find(
        "{% set hidden_floors = [] %}{% set hidden_areas = [] %}{% set included_labels = [] %}") == 0);
    return true;
}

(:test)
function hiddenSetsAreInlinedAsQuotedIds(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.GLANCE, { "floor.up" => true }, { "area.a" => true },
        [] as Array<String>);

    Test.assert(template.find("{% set hidden_floors = ['floor.up'] %}{% set hidden_areas = ['area.a'] %}") == 0);
    Test.assert(template.find("(floor_id(area) or 'floorless-areas') not in hidden_floors") != null);
    return true;
}

(:test)
function severalIdsAreCommaSeparated(logger as Test.Logger) as Boolean {
    Test.assertEqual(HaTemplate.quoteIds(["a", "b"] as Array<String>), "'a','b'");
    return true;
}

(:test)
function theStructureTemplateIsNeverFiltered(logger as Test.Logger) as Boolean {
    Test.assertEqual(
        HaTemplate.resolve(FetchTarget.STRUCTURE, { "floor.up" => true }, {}, ["label.a"] as Array<String>),
        HaTemplate.STRUCTURE);
    return true;
}

(:test)
function theStructureTemplateEmitsTheLabelRegistry(logger as Test.Logger) as Boolean {
    Test.assert(HaTemplate.STRUCTURE.find("label_name(label)") != null);
    Test.assert(HaTemplate.STRUCTURE.find("labels=ns.labels") != null);
    return true;
}

(:test)
function theWatchedLabelUnionRunsOutsideTheVisibleClause(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.LIGHTS, {}, {}, ["label.watched"] as Array<String>);

    Test.assert(template.find("{% set included_labels = ['label.watched'] %}") != null);

    // The label loop is a sibling after the visible-area loop closes, never nested
    // inside its clause, so a hidden-area labelled entity still arrives.
    Test.assert(template.find(
        "{% endfor %}{% for label in included_labels %}{% for entity in label_entities(label) %}") != null);
    return true;
}

(:test)
function theGlanceTemplateHasNoWatchedLabelUnion(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.GLANCE, {}, {}, ["label.watched"] as Array<String>);

    Test.assert(template.find("label_entities(label)") == null);
    return true;
}
