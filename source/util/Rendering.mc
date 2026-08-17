import Toybox.Graphics;
import Toybox.Lang;

module Rendering {

    function useAntiAlias(dc as Graphics.Dc, enabled as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(enabled);
        }
    }
}
