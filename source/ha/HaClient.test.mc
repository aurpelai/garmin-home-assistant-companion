import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Captures each entry point's callback instead of making a web request, so a
// test can fire success or failure synchronously.
(:test)
class FakeHaClient extends HaClient {
    private var _fetchCallback as Method?;
    private var _serviceCallback as Method?;
    private var _registerCallback as Method?;

    // Only the latest callback is kept, so this counter is how a test tells zero
    // calls from one.
    public var toggleCount as Number;
    public var registerCount as Number;
    public var fetchOnceCount as Number;

    function initialize() {
        HaClient.initialize();
        toggleCount = 0;
        registerCount = 0;
        fetchOnceCount = 0;
    }

    function fetchHomeState(callback as Method) as Void {
        _fetchCallback = callback;
    }

    function toggleLight(entityId as String, callback as Method) as Void {
        _serviceCallback = callback;
        toggleCount++;
    }

    function register(callback as Method) as Void {
        _registerCallback = callback;
        registerCount++;
    }

    function fetchOnce(callback as Method) as Void {
        _fetchCallback = callback;
        fetchOnceCount++;
    }

    function serviceOnce(entityId as String, callback as Method) as Void {
        _serviceCallback = callback;
        toggleCount++;
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

    function fireServiceSuccess() as Void {
        (_serviceCallback as Method).invoke(true, null);
    }

    function fireServiceFailure() as Void {
        (_serviceCallback as Method).invoke(null, -1);
    }

    function fireServiceFailureWithCode(code as Number) as Void {
        (_serviceCallback as Method).invoke(null, code);
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
            "areas" => { "Room" => ["light.a"] },
            "states" => { "light.a" => true }
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
function registerIfNeededRegistersWhenNoCachedWebhookId(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new FakeHaClient();

    Settings.registerIfNeeded(client, new NoopRegisterCompletion().method(:onRegistered));

    Test.assertEqual(client.registerCount, 1);
    return true;
}

(:test)
function registerIfNeededNoOpsWhenUrlUnchangedWithCachedId(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("existing-id");
    Settings.setRegisteredUrl(Settings.getBaseUrl());
    var client = new FakeHaClient();

    Settings.registerIfNeeded(client, new NoopRegisterCompletion().method(:onRegistered));

    Test.assertEqual(client.registerCount, 0);
    return true;
}

(:test)
function registerIfNeededReRegistersAfterUrlChange(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    Settings.setRegisteredUrl("https://old.example.com");
    var client = new FakeHaClient();

    Settings.registerIfNeeded(client, new NoopRegisterCompletion().method(:onRegistered));

    Test.assertEqual(client.registerCount, 1);
    Test.assert(Settings.getWebhookId() == null);
    return true;
}

(:test)
function registerIfNeededNoOpsOnTokenOnlyChange(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("existing-id");
    Settings.setRegisteredUrl(Settings.getBaseUrl());
    var client = new FakeHaClient();

    // A token-only change never touches Storage's registeredUrl, so the gate
    // sees the same URL it cached and must not re-register.
    Settings.registerIfNeeded(client, new NoopRegisterCompletion().method(:onRegistered));

    Test.assertEqual(client.registerCount, 0);
    return true;
}

(:test)
function fetchHomeStateRecoversOnceFromInvalidWebhook(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    var client = new FakeHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, client.method(:fetchOnce), capture.method(:onResult)).attempt();
    client.fireFetchFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);

    Test.assertEqual(client.fetchOnceCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result == null);
    Test.assertEqual(capture.error as Number, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    return true;
}

(:test)
function fetchHomeStateRecoversFrom404TooAndSucceeds(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    var client = new FakeHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, client.method(:fetchOnce), capture.method(:onResult)).attempt();
    client.fireFetchFailureWithCode(404);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchSuccess(HomeState.fromTemplateData({
        "areas" => { "Room" => ["light.a"] },
        "states" => { "light.a" => true }
    }));

    Test.assertEqual(client.fetchOnceCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result instanceof HomeState);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function toggleLightRecoversOnceFromInvalidWebhook(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Settings.setWebhookId("stale-id");
    var client = new FakeHaClient();
    var capture = new ResultCapture();

    new RecoveryHandler(client, new ServiceOnceHandler(client, "light.a").method(:serviceOnce),
        capture.method(:onResult)).attempt();
    client.fireServiceFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    client.fireRegisterSuccess("fresh-id");
    client.fireServiceSuccess();

    Test.assertEqual(client.toggleCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
class NoopRegisterCompletion {
    function onRegistered(webhookId as String or Null, error as Number or Null) as Void {
    }
}
