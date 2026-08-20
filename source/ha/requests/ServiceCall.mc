import Toybox.Lang;

// Binds a light-domain service call to one target, so a per-call instance
// exposes the single-callback-argument shape RetryManager requires. A light
// toggle passes the toggle service with an entity_id key; a floor action
// passes its own service with a floor_id key.
class ServiceCall {
    private var _client as HaClient;
    private var _service as String;
    private var _targetKey as String;
    private var _targetId as String;

    function initialize(client as HaClient, service as String, targetKey as String, targetId as String) {
        _client = client;
        _service = service;
        _targetKey = targetKey;
        _targetId = targetId;
    }

    function attempt(callback as Method) as Void {
        var body = {
            "type" => "call_service",
            "data" => {
                "domain" => "light",
                "service" => _service,
                "service_data" => {
                    _targetKey => _targetId
                }
            }
        };

        new WebhookPost(_client, body, ResponseType.SERVICE_CALL,
                        Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON).attempt(callback);
    }

}
