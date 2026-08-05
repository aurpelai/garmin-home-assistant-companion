import Toybox.Lang;

// Binds a floorId and direction to HaClient.callFloorService, exposing the
// single-callback-argument shape RecoveryHandler requires.
class FloorServiceCallHandler {
    private var _client as HaClient;
    private var _floorId as String;
    private var _service as String;

    function initialize(client as HaClient, floorId as String, service as String) {
        _client = client;
        _floorId = floorId;
        _service = service;
    }

    function callFloorService(callback as Method) as Void {
        var webhookId = Settings.getWebhookId();

        if (webhookId == null) {
            callback.invoke(null, 404);
            return;
        }

        var body = {
            "type" => "call_service",
            "data" => {
                "domain" => "light",
                "service" => _service,
                "service_data" => {
                    "floor_id" => _floorId
                }
            }
        };

        _client.post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, :onService));
    }

}
