import Toybox.Lang;

// A screen built around a subject that can vanish from a fresh state — the area
// or floor a menu shows, or the empty home the loading screen waits on.
typedef Perishable as interface {
    function hasPerished(haState as HaState) as Boolean;
};
