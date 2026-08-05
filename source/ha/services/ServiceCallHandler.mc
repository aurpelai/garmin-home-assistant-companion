import Toybox.Lang;

// Binds an entityId to HaClient.callService, so a per-toggle instance exposes
// the single-callback-argument shape RecoveryHandler's attemptOnce requires.
class ServiceCallHandler {
    private var _client as HaClient;
    private var _entityId as String;

    function initialize(client as HaClient, entityId as String) {
        _client = client;
        _entityId = entityId;
    }

    function callService(callback as Method) as Void {
        var webhookId = Settings.getWebhookId();

        if (webhookId == null) {
            callback.invoke(null, 404);
            return;
        }

        var body = {
            "type" => "call_service",
            "data" => {
                "domain" => "light",
                "service" => "toggle",
                "service_data" => {
                    "entity_id" => _entityId
                }
            }
        };

        _client.post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, :onService));
    }

}

