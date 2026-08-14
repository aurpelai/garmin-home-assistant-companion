import Toybox.Lang;

// A live view the coordinator pushes fresh state into. Implemented rather than
// extended: every menu view's single base slot is taken by Menu2, and a
// structural interface needs no slot at all.
//
// The return says whether the view's subject still exists — false means the
// screen it stood for is gone, which the coordinator answers by navigating.
typedef Screen as interface {
    function rebuild(haState as HaState) as Boolean;
};
