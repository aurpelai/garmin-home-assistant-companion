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
    const TEMPLATE_RENDER_ROOT_KEY = "home";
}
