import Toybox.Lang;

// Binds a floorId and direction to HaClient.callFloorService, exposing the
// single-callback-argument shape RecoveryHandler requires.
class CallFloorServiceHandler {
    private var _client as HaClient;
    private var _floorId as String;
    private var _service as String;

    function initialize(client as HaClient, floorId as String, service as String) {
        _client = client;
        _floorId = floorId;
        _service = service;
    }

    function callFloorService(callback as Method) as Void {
        _client.callFloorService(_floorId, _service, callback);
    }
}
