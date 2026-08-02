import Toybox.Lang;

// Binds a floorId and direction to HaClient.floorServiceOnce, so a per-toggle
// instance exposes the single-callback-argument shape RecoveryHandler's
// attemptOnce requires.
class FloorServiceOnceHandler {
    private var _client as HaClient;
    private var _floorId as String;
    private var _service as String;

    function initialize(client as HaClient, floorId as String, service as String) {
        _client = client;
        _floorId = floorId;
        _service = service;
    }

    function serviceOnce(callback as Method) as Void {
        _client.floorServiceOnce(_floorId, _service, callback);
    }
}
