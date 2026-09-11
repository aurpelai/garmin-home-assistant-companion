import Toybox.Lang;
import Toybox.Test;

(:test)
function anUnresolvedVisibleSetRendersUnfiltered(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.LIGHTS, null);

    Test.assert(template.find("{% set visible = none %}") == 0);
    return true;
}

(:test)
function anEmptyVisibleSetHidesEveryArea(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.LIGHTS, [] as Array<String>);

    Test.assert(template.find("{% set visible = [] %}") == 0);
    return true;
}

(:test)
function aResolvedVisibleSetInlinesQuotedAreaIds(logger as Test.Logger) as Boolean {
    var template = HaTemplate.resolve(FetchTarget.GLANCE, ["area.a", "area.b"] as Array<String>);

    Test.assert(template.find("{% set visible = ['area.a','area.b'] %}") == 0);
    return true;
}

(:test)
function theStructureTemplateIsNeverFiltered(logger as Test.Logger) as Boolean {
    Test.assertEqual(HaTemplate.resolve(FetchTarget.STRUCTURE, ["area.a"] as Array<String>), HaTemplate.STRUCTURE);
    return true;
}
