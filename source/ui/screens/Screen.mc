import Toybox.Lang;

// The top-level element the coordinator has on the display and drives: a CIQ
// View or Menu2 that reports its own show and hide. Perishable and Refreshable
// are optional capabilities a screen may also satisfy, probed with `has` — a
// static screen such as a message satisfies neither.
typedef Screen as interface {
    function onShow() as Void;
    function onHide() as Void;
};
