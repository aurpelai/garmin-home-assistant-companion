import Toybox.Lang;
import Toybox.Test;

// FakeHaClient and CompletionSpy are the transport test double and its
// completion-observation helper: reused by HomeSession's async-branch tests.
// ResponseHandler's normalization is pure and synchronous, so it is exercised
// directly below with no fake needed.

// Captures the callback each entry point is handed instead of making a web
// request, and exposes methods to fire it with a chosen success or failure.
(:test)
class FakeHaClient extends HaClient {
    private var _fetchCallback as Method?;
    private var _serviceCallback as Method?;

    // Only the latest callback is kept, so a test asserting that a row fired
    // nothing needs this counter to tell no call from one call.
    public var toggleCount as Number;

    function initialize() {
        HaClient.initialize();
        toggleCount = 0;
    }

    function fetchHomeState(callback as Method) as Void {
        _fetchCallback = callback;
    }

    function toggleLight(entityId as String, callback as Method) as Void {
        _serviceCallback = callback;
        toggleCount++;
    }

    function fireFetchSuccess(state as HomeState) as Void {
        (_fetchCallback as Method).invoke(state, null);
    }

    function fireFetchFailure() as Void {
        (_fetchCallback as Method).invoke(null, -1);
    }

    function fireServiceSuccess() as Void {
        (_serviceCallback as Method).invoke(true, null);
    }

    function fireServiceFailure() as Void {
        (_serviceCallback as Method).invoke(null, -1);
    }
}

// Observes a nullary completion callback firing. Monkey C closures can't
// capture mutable locals, so this is the only way a test can tell whether
// refreshState's onDone or toggleState's onComplete actually ran.
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

// Captures a ResponseHandler's normalized (result, error) pair for direct
// assertion.
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

    handler.onResponse(200, {
        "areas" => { "Room" => ["light.a"] },
        "states" => { "light.a" => true }
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
