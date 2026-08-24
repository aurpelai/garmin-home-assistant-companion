import Toybox.Lang;

// How a successful body is read. Each shape carries its payload differently, so
// a 2xx alone does not say what arrived.
class ResponseType {
    static const TEMPLATE_RENDER = :templateRender;
    static const REGISTRATION = :registration;
    static const SERVICE_CALL = :serviceCall;

    // The single name our template is registered under in the request; the
    // webhook echoes its render back under the same key (see #73).
    static const TEMPLATE_RENDER_ROOT_KEY = "home";
}
