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
            _callback.invoke(null, code);
            return;
        }
        switch (_responseType) {
            case :fetch:
                var rendered = (data instanceof Dictionary) ? data.get("home") : null;
                // The render_template webhook returns the rendered value as a
                // string, so the payload arrives JSON-encoded a second time.
                var home = (rendered instanceof Lang.String) ? JsonParser.parse(rendered) : rendered;
                if (home == null) {
                    _callback.invoke(null, RequestError.UNREADABLE_BODY);
                } else {
                    _callback.invoke(home, null);
                }
                break;
            case :registration:
                var webhookId = (data instanceof Dictionary) ? data.get("webhook_id") : null;
                if (webhookId instanceof Lang.String) {
                    _callback.invoke(webhookId, null);
                } else {
                    // Report an error code, not the 200: a body without a usable
                    // webhook_id is a failure the error channel must carry.
                    _callback.invoke(null, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
                }
                break;
            case :serviceCall:
                _callback.invoke(true, null);
                break;
        }
    }
}
