import Toybox.Lang;

typedef SubLabelProvider as interface {
    function getOff() as String;
    function getUnavailable() as String;
    function getGroupUnavailable() as String;
    function resolveGroupLabel(domain as String, memberCount as Number) as String;
    function formatPercent(percent as Number) as String;
};
