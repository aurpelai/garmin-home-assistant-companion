import Toybox.Lang;
import Toybox.Test;

(:test)
function aGroupLabelCountsItsMembersInTheDomainsOwnWords(logger as Test.Logger) as Boolean {
    var provider = new ResourceSubLabelProvider();

    Test.assertEqual(provider.resolveGroupLabel("light", 1), "Group • 1 Light");
    Test.assertEqual(provider.resolveGroupLabel("light", 4), "Group • 4 Lights");
    Test.assertEqual(provider.resolveGroupLabel("fan", 1), "Group • 1 Fan");
    Test.assertEqual(provider.resolveGroupLabel("fan", 3), "Group • 3 Fans");
    return true;
}

(:test)
function anOnEntityReadsItsValueAfterABullet(logger as Test.Logger) as Boolean {
    var provider = new ResourceSubLabelProvider();

    Test.assertEqual(provider.getOn(), "On");
    Test.assertEqual(provider.formatValue(50), "On • 50 %");
    return true;
}
