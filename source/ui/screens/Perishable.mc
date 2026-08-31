import Toybox.Lang;

// A screen whose subject can vanish from a fresh state — the area or floor it
// was built around, or an empty home the loading screen waits on. When it has,
// the coordinator retreats to the card loop rather than keeping a screen whose
// subject is gone.
typedef Perishable as interface {
    function hasPerished(haState as HaState) as Boolean;
};
