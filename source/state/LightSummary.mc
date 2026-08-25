import Toybox.Lang;

// The tokens Home Assistant's lightSummary reduction emits, shared by everything
// that reads them: the card loop, the glance, and the background service.
(:glance, :background)
module LightSummary {
    const ALL_ON = "all_on";
    const SOME_ON = "some_on";
    const ALL_OFF = "all_off";
}
