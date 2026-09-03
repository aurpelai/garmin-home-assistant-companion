import Toybox.Lang;
import Toybox.WatchUi;

// The only object that loads a row's sublabel from Rez.Strings, so the menu
// builder resolves every sublabel without touching WatchUi.
class ResourceSubLabelProvider {
    function getOff() as String {
        return WatchUi.loadResource(Rez.Strings.Off) as String;
    }

    function getUnavailable() as String {
        return WatchUi.loadResource(Rez.Strings.Unavailable) as String;
    }

    function getGroupUnavailable() as String {
        return WatchUi.loadResource(Rez.Strings.GroupUnavailable) as String;
    }

    function resolveGroupLabel(domain as String, memberCount as Number) as String {
        var isFan = domain.equals(Domain.FAN);

        if (memberCount == 1) {
            return WatchUi.loadResource(
                isFan ? Rez.Strings.GroupFanCountOne : Rez.Strings.GroupLightCountOne) as String;
        }

        return Lang.format(WatchUi.loadResource(
            isFan ? Rez.Strings.GroupFanCount : Rez.Strings.GroupLightCount) as String, [memberCount]);
    }

    function formatPercent(percent as Number) as String {
        return Lang.format(WatchUi.loadResource(Rez.Strings.Percent) as String, [percent]);
    }
}
