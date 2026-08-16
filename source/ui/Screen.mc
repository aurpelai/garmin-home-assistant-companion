import Toybox.Lang;

typedef Screen as interface {
    function isObsolete(haState as HaState) as Boolean;
    function rebuild(haState as HaState) as Void;
};
