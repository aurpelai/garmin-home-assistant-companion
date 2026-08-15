import Toybox.Lang;

// How a successful body is read. Each shape carries its payload differently, so
// a 2xx alone does not say what arrived.
class ResponseType {
    static const FETCH = :fetch;
    static const REGISTRATION = :registration;
    static const SERVICE_CALL = :serviceCall;
}
