import Toybox.Lang;

// A screen that absorbs a fresh state in place, updating what it draws without
// being rebuilt from scratch.
typedef Refreshable as interface {
    function rebuild(haState as HaState) as Void;
};
