import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Captures each entry point's callback instead of making a web request, so a
// test can fire success or failure synchronously.
(:test)
class MockHaClient extends HaClient {
    private var _fetchCallback as Method?;
    private var _registerCallback as Method?;

    // A list, not a single slot, so a test can fire an earlier in-flight toggle
    // after a later one began.
    public var serviceCallbacks as Array<Method> = [];

    // Callback capture alone can't distinguish "never called" from "called
    // once", so these count the calls.
    public var toggleCount as Number;
    public var registerCount as Number;
    public var fetchCount as Number;
    public var floorToggleCount as Number;
    public var lastFloorService as String?;

    function initialize() {
        HaClient.initialize();
        toggleCount = 0;
        registerCount = 0;
        fetchCount = 0;
        floorToggleCount = 0;
    }

    function fetchHomeState(callback as Method) as Void {
        _fetchCallback = callback;
    }

    function toggleLight(entityId as String, callback as Method) as Void {
        serviceCallbacks.add(callback);
        toggleCount++;
    }

    function register(callback as Method) as Void {
        _registerCallback = callback;
        registerCount++;
    }

    function fetch(callback as Method) as Void {
        _fetchCallback = callback;
        fetchCount++;
    }

    function callService(entityId as String, callback as Method) as Void {
        serviceCallbacks.add(callback);
        toggleCount++;
    }

    function toggleFloorLights(floorId as String, service as String, callback as Method) as Void {
        serviceCallbacks.add(callback);
        lastFloorService = service;
        floorToggleCount++;
    }

    function fireFetchSuccess(state as HomeState) as Void {
        (_fetchCallback as Method).invoke(state, null);
    }

    function fireFetchFailure() as Void {
        (_fetchCallback as Method).invoke(null, -1);
    }

    function fireFetchFailureWithCode(code as Number) as Void {
        (_fetchCallback as Method).invoke(null, code);
    }

    function fireServiceSuccessAt(index as Number) as Void {
        serviceCallbacks[index].invoke(true, null);
    }

    function fireServiceFailureAt(index as Number, code as Number) as Void {
        serviceCallbacks[index].invoke(null, code);
    }

    function fireRegisterSuccess(webhookId as String) as Void {
        (_registerCallback as Method).invoke(webhookId, null);
    }

    function fireRegisterFailure() as Void {
        (_registerCallback as Method).invoke(null, -1);
    }
}

// Monkey C closures can't capture mutable locals, so a test needs this object
// to observe whether a nullary completion callback fired.
(:test)
class CompletionSpy {
    public var fired as Boolean;

    function initialize() {
        fired = false;
    }

    function onDone() as Void {
        fired = true;
    }

    function onComplete() as Void {
        fired = true;
    }
}

(:test)
class ResultCapture {
    public var result as Object?;
    public var error as Number?;

    function onResult(result as Object?, error as Number?) as Void {
        self.result = result;
        self.error = error;
    }
}

(:test)
function onResponseNormalizesNon200ToError(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), :onTemplate);

    handler.onResponse(401, null);

    Test.assert(capture.result == null);
    Test.assertEqual(capture.error as Number, 401);
    return true;
}

(:test)
function onResponseNormalizesTemplateSuccessToHomeState(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), :onTemplate);

    // The webhook wraps the rendered payload under a "home" key.
    handler.onResponse(200, {
        "home" => {
            "areas" => { "area.room" => { "name" => "Room", "lights" => ["light.a"] } },
            "lights" => { "light.a" => { "state" => true } }
        }
    });

    Test.assert(capture.result instanceof HomeState);
    Test.assert((capture.result as HomeState).isOn("light.a"));
    Test.assert(capture.error == null);
    return true;
}

(:test)
function onResponseNormalizesServiceSuccessToTrue(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), :onService);

    handler.onResponse(200, null);

    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function onResponseNormalizesRegisterSuccessToWebhookId(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), :onRegister);

    // HA returns 201 Created for /api/mobile_app/registrations.
    handler.onResponse(201, { "webhook_id" => "abc123" });

    Test.assertEqual(capture.result as String, "abc123");
    Test.assert(capture.error == null);
    return true;
}

(:test)
function onResponseNormalizesRegisterFailureToError(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), :onRegister);

    handler.onResponse(400, null);

    Test.assert(capture.result == null);
    Test.assertEqual(capture.error as Number, 400);
    return true;
}

(:test)
function fetchHomeStateRecoversOnceFromInvalidWebhook(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, client.method(:fetch), capture.method(:onResult)).attempt();
    client.fireFetchFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);

    Test.assertEqual(client.fetchCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result == null);
    Test.assertEqual(capture.error as Number, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    return true;
}

(:test)
function fetchHomeStateRecoversFrom404TooAndSucceeds(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, client.method(:fetch), capture.method(:onResult)).attempt();
    client.fireFetchFailureWithCode(404);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchSuccess(HomeState.fromTemplateData({
        "areas" => { "area.room" => { "name" => "Room", "lights" => ["light.a"] } },
        "lights" => { "light.a" => { "state" => true } }
    }));

    Test.assertEqual(client.fetchCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result instanceof HomeState);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function fetchHomeStateSurfacesAuthFailureWithoutReRegistering(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("valid-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, client.method(:fetch), capture.method(:onResult)).attempt();
    client.fireFetchFailureWithCode(401);

    Test.assertEqual(client.registerCount, 0);
    Test.assertEqual(client.fetchCount, 1);
    Test.assertEqual(capture.error as Number, 401);
    Test.assertEqual(Settings.getWebhookId() as String, "valid-id");
    return true;
}

(:test)
function toggleLightRecoversOnceFromInvalidWebhook(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, new ServiceCallHandler(client, "light.a").method(:callService),
        capture.method(:onResult)).attempt();
    client.fireServiceFailureAt(0, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    client.fireRegisterSuccess("fresh-id");
    client.fireServiceSuccessAt(0);

    Test.assertEqual(client.toggleCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}
