import Toybox.Lang;
import Toybox.Test;

(:test)
function emptyHiddenSetsRenderUnfiltered(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.LIGHTS, {}, {});

    Test.assert(template.find("{% set hidden_floors = [] %}{% set hidden_areas = [] %}") == 0);
    return true;
}

(:test)
function hiddenSetsAreInlinedAsQuotedIds(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.GLANCE, { "floor.up" => true }, { "area.a" => true });

    Test.assert(template.find("{% set hidden_floors = ['floor.up'] %}{% set hidden_areas = ['area.a'] %}") == 0);
    Test.assert(template.find("(floor_id(a) or 'unfloored-areas') not in hidden_floors") != null);
    return true;
}

(:test)
function severalIdsAreCommaSeparated(logger as Test.Logger) as Boolean {
    Test.assertEqual(HaTemplate.quoteIds(["a", "b"] as Array<String>), "'a','b'");
    return true;
}

(:test)
function theStructureTemplateIsNeverFiltered(logger as Test.Logger) as Boolean {
    Test.assertEqual(HaTemplate.resolve(FetchTarget.STRUCTURE, { "floor.up" => true }, {}), HaTemplate.STRUCTURE);
    return true;
}
