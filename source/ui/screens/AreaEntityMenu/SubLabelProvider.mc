import Toybox.Lang;

typedef SubLabelProvider as interface {
    function getOff() as String;
    function getUnavailable() as String;
    function getGroupUnavailable() as String;
    function getGroupCount(domain as String, memberCount as Number) as String;
};
