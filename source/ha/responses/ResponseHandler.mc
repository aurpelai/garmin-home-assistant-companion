import Toybox.Lang;

class ResponseHandler {
    private var _callback as Method;
    private var _responseType as Symbol;

    function initialize(callback as Method, responseType as Symbol) {
        _callback = callback;
        _responseType = responseType;
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code < 200 || code >= 300) {
            System.println("HA request failed: responseType=" + _responseType + " code=" + code + " body=" + data);
            fail(code);
            return;
        }
        switch (_responseType) {
            case ResponseType.TEMPLATE_RENDER:
                // A dead webhook answers 200 with an empty body, so the render
                // never arrives as the expected envelope (see #68). That is the
                // id being gone rather than an unreadable render.
                if (!(data instanceof Dictionary)) {
                    fail(RequestError.UNUSABLE_WEBHOOK);
                    return;
                }

                var rendered = data.get(ResponseType.TEMPLATE_RENDER_ROOT_KEY);

                if (!(rendered instanceof Dictionary)) {
                    fail(RequestError.UNREADABLE_BODY);
                    return;
                }

                if (ResponseType.isRenderError(rendered)) {
                    fail(RequestError.TEMPLATE_ERROR);
                    return;
                }

                _callback.invoke(rendered, null);
                break;
            case ResponseType.REGISTRATION:
                var webhookId = (data instanceof Dictionary) ? data.get("webhook_id") : null;

                if (!(webhookId instanceof Lang.String)) {
                    fail(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
                    return;
                }

                _callback.invoke(webhookId, null);
                break;
            case ResponseType.SERVICE_CALL:
                _callback.invoke(true, null);
                break;
        }
    }

    private function fail(reason as Number or Symbol) as Void {
        _callback.invoke(null, new RequestError(reason, _responseType == ResponseType.REGISTRATION
            ? RequestType.REGISTRATION
            : null));
    }
}
