import Toybox.Lang;

// The top-level element the coordinator drives: a CIQ View or Menu2, reporting
// its own show and hide. Perishable and Refreshable are optional capabilities.
typedef Screen as interface {
    function onShow() as Void;
    function onHide() as Void;
};
