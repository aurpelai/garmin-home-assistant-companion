import Toybox.Lang;

// How a successful body is read. Each shape carries its payload differently, so
// a 2xx alone does not say what arrived.
(:background)
module ResponseType {
    const TEMPLATE_RENDER = :templateRender;
    const REGISTRATION = :registration;
    const SERVICE_CALL = :serviceCall;

    // The single name our template is registered under in the request; the
    // webhook echoes its render back under the same key (see #73).
    const TEMPLATE_RENDER_ROOT_KEY = "data";

    // A template that fails to render comes back as a 200 carrying an error
    // object in place of the render (verified from the Home Assistant core
    // source on 2026-09-12).
    function isRenderError(rendered as Dictionary) as Boolean {
        return rendered.get("error") instanceof String;
    }
}
