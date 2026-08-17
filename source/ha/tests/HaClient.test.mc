import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Restates a posted request's ResponseHandler as the (result, error) shape the
// toggle entry points capture, so every recorded callback fires the same way.
//
// A success carries a rendered body, since a fetch reply without one is a
// failure rather than an empty home. The service-call branch reads no body, so
// the same shape serves both request types the mock posts.
(:test)
class PostedRequest {
    private const RENDERED_EMPTY_HOME = { "home" => "{}" };

    private var _handler as ResponseHandler;

    function initialize(handler as ResponseHandler) {
        _handler = handler;
    }

    function respond(result as Object?, code as Number?) as Void {
        if (code != null) {
            _handler.onResponse(code, null);
            return;
        }

        _handler.onResponse(200, RENDERED_EMPTY_HOME);
    }
}

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

    function initialize() {
        HaClient.initialize();
        toggleCount = 0;
        registerCount = 0;
        fetchCount = 0;
    }

    // Stands in for any request the retry manager reissues: what those tests
    // pin is the reissue, not which request happened to be the vehicle.
    function fetchOnce(callback as Method) as Void {
        _fetchCallback = callback;
        fetchCount++;
    }

    function register(callback as Method) as Void {
        _registerCallback = new RegistrationHandler(callback).method(:onRegistered);
        registerCount++;
    }

    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        serviceCallbacks.add(new PostedRequest(handler).method(:respond));
        toggleCount++;
    }

    function fireFetchSuccess(payload as Dictionary) as Void {
        (_fetchCallback as Method).invoke(payload, null);
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

    function fireRegisterFailureWithCode(code as Number) as Void {
        (_registerCallback as Method).invoke(null, code);
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

// Sits at two layers: below RetryManager an error is the raw reason a response
// yielded, above it the RequestError the retry loop surfaced. The field is as
// wide as both, and each test asserts the shape its own layer produces.
(:test)
class ResultCapture {
    public var result as Object?;
    public var error as Object?;

    function onResult(result as Object?, error as Object?) as Void {
        self.result = result;
        self.error = error;
    }
}

(:test)
function onResponseNormalizesNon200ToError(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.FETCH);

    handler.onResponse(401, null);

    Test.assert(capture.result == null);
    Test.assertEqual(capture.error as Number, 401);
    return true;
}

(:test)
function onResponseHandsOutTheRawFetchPayload(logger as Test.Logger) as Boolean {
    // ResponseHandler stays domain-ignorant: a fetch reply is the parsed
    // dictionary under "home", never a domain type the transport layer would
    // have to name.
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.FETCH);

    handler.onResponse(200, {
        "home" => { "lights" => { "light.a" => { "state" => true } } }
    });

    Test.assert(capture.result instanceof Dictionary);
    Test.assertEqual(((capture.result as Dictionary).get("lights") as Dictionary).size(), 1);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function aFetchBodyThatCannotBeReadIsAFailureNotAnEmptyHome(logger as Test.Logger) as Boolean {
    // The distinction the error path exists to keep: an unreadable reply and a
    // home with nothing in it both yield no entities, so passing this off as a
    // success would tell a broken instance it is merely empty.
    var missingSection = new ResultCapture();
    new ResponseHandler(missingSection.method(:onResult), ResponseType.FETCH).onResponse(200, {});

    Test.assert(missingSection.result == null);
    Test.assertEqual(missingSection.error as Symbol, RequestError.UNREADABLE_BODY);

    var unparsable = new ResultCapture();
    new ResponseHandler(unparsable.method(:onResult), ResponseType.FETCH).onResponse(200, { "home" => "{not json" });

    Test.assert(unparsable.result == null);
    Test.assertEqual(unparsable.error as Symbol, RequestError.UNREADABLE_BODY);

    // A home that genuinely rendered empty still reads as a success: emptiness
    // is the info view's finding, not the error path's.
    var empty = new ResultCapture();
    new ResponseHandler(empty.method(:onResult), ResponseType.FETCH).onResponse(200, { "home" => "{}" });

    Test.assert(empty.result instanceof Dictionary);
    Test.assert(empty.error == null);
    return true;
}

(:test)
function onResponseNormalizesServiceCallSuccessToTrue(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.SERVICE_CALL);

    handler.onResponse(200, null);

    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function onResponseNormalizesRegistrationSuccessToWebhookId(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.REGISTRATION);

    // HA returns 201 Created for /api/mobile_app/registrations.
    handler.onResponse(201, { "webhook_id" => "abc123" });

    Test.assertEqual(capture.result as String, "abc123");
    Test.assert(capture.error == null);
    return true;
}

(:test)
function aFetchRecoversOnceFromInvalidWebhook(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Webhook.setId("stale-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RetryManager(client, client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchFailureWithCode(Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);

    Test.assertEqual(client.fetchCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result == null);

    // The request that failed is what the error names: the re-registration
    // succeeded, so the fetch behind it owns this failure.
    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function toggleLightRecoversOnceFromInvalidWebhook(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Webhook.setId("stale-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RetryManager(client, new ServiceCall(client, "toggle", "entity_id", "light.a").method(:attempt),
        capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireServiceFailureAt(0, Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE);
    client.fireRegisterSuccess("fresh-id");
    client.fireServiceSuccessAt(1);

    Test.assertEqual(client.toggleCount, 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerReissuesOnAnyOtherFailureUpToTheThreshold(logger as Test.Logger) as Boolean {
    // Every reason is retried, not just an invalid webhook id: nothing
    // classifies a failure, so an ordinary transport error is reissued too.
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RetryManager(client, client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailureWithCode(-1);
    client.fireFetchFailureWithCode(-1);
    client.fireFetchSuccess({} as Dictionary);

    Test.assertEqual(client.fetchCount, 3);
    Test.assertEqual(client.registerCount, 0);
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerSurfacesTheFailureOnceItsThresholdIsSpent(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RetryManager(client, client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailureWithCode(-1);
    client.fireFetchFailureWithCode(-1);
    client.fireFetchFailureWithCode(-1);
    client.fireFetchFailureWithCode(-1);

    Test.assert(capture.result == null);

    // A spent threshold is the only thing that produces an error at all, and it
    // carries the identity of the request that spent it.
    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, -1);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aRegistrationFailureInsideFetchRecoveryStaysARegistrationFailure(logger as Test.Logger) as Boolean {
    // The one site where two request types interleave. Flattening this to the
    // fetch would do real damage: a bad request against our registration body
    // means our own body is malformed, while the same code on a fetch means a
    // template error on the Home Assistant side.
    Application.Storage.clearValues();
    Webhook.setId("stale-id");
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RetryManager(client, client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailureWithCode(404);
    client.fireRegisterFailureWithCode(400);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, 400);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    return true;
}

// Drives HaClient's new split-payload surface directly. Both a refresh
// target and a queued change end up posted through the same mocked post(),
// so serviceCallbacks/toggleCount (the shared "request reached transport"
// seam) is what every assertion below reads, whichever kind fired it.
// Webhook.setId is called first so a target's own request does not itself
// fail with the "unregistered" 404 the client returns for a missing id.

(:test)
class TargetLog {
    public var targets as Array<Symbol> = [];
    public var results as Array<Object?> = [];
    public var errors as Array<RequestError?> = [];

    function onTarget(target as Symbol, result as Object?, error as RequestError or Null) as Void {
        targets.add(target);
        results.add(result);
        errors.add(error);
    }
}

(:test)
function aChangeQueuesRatherThanBeingDropped(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", first.method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));

    // The first tap occupies the slot; the second is still queued rather than
    // discarded, so it fires only once the first settles.
    Test.assertEqual(client.serviceCallbacks.size(), 1);
    client.fireServiceSuccessAt(0);
    Test.assertEqual(client.serviceCallbacks.size(), 2);
    return true;
}

(:test)
function changesGoOutBeforeFetches(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));

    // The refresh's first target already occupies the slot when the toggle is
    // queued; once it settles, the queued change must go out before the
    // refresh's next target does.
    Test.assertEqual(client.serviceCallbacks.size(), 1);
    client.fireServiceSuccessAt(0);
    Test.assertEqual(client.serviceCallbacks.size(), 2);
    Test.assertEqual(log.targets.size(), 1);
    return true;
}

(:test)
function aRefreshTriggeredWhileOneIsIncompleteIsDropped(logger as Test.Logger) as Boolean {
    // Both refreshes are driven all the way to completion: if the second
    // trigger were merely deferred rather than dropped, its own three
    // targets would still fire once the first refresh finished, and the
    // total would be 6 rather than 3.
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.refresh(log.method(:onTarget));

    client.fireServiceSuccessAt(0);
    client.fireServiceSuccessAt(1);
    client.fireServiceSuccessAt(2);

    Test.assertEqual(client.serviceCallbacks.size(), 3);
    Test.assertEqual(log.targets.size(), 3);
    return true;
}

(:test)
function aReplyDoesNotStartARefreshWhileChangesAreQueued(logger as Test.Logger) as Boolean {
    // Simulates the coordinator asking for a refresh right after a toggle's
    // own reply, with a second toggle still queued behind it: the refresh
    // trigger must be dropped, since converging against server truth is
    // pointless when more changes are about to be posted.
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var log = new TargetLog();

    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));
    client.queueLightToggle("light.b", new ResultCapture().method(:onResult));
    client.refresh(log.method(:onTarget));

    Test.assertEqual(log.targets.size(), 0);
    return true;
}

(:test)
function theQueueDrainsOnlyOnceTheThresholdIsExhausted(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", first.method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));

    // One failure is a hypothesis, not a verdict: RetryManager reissues the
    // first toggle on its own (indices 1, 2, 3 below are its own reissues),
    // and the second tap must still be waiting in the queue throughout —
    // untouched by any of them.
    client.fireServiceFailureAt(0, -1);
    client.fireServiceFailureAt(1, -1);
    client.fireServiceFailureAt(2, -1);
    Test.assertEqual(client.serviceCallbacks.size(), 4);
    Test.assert(first.error == null);
    Test.assert(second.result == null);
    Test.assert(second.error == null);

    // The fourth failure exhausts RetryManager's threshold, which is what
    // finally drains the second tap: it is discarded, not fired, and its
    // callback is never invoked — one signal for one cause, not one per
    // queued change.
    client.fireServiceFailureAt(3, -1);

    Test.assertEqual((first.error as RequestError).reason as Number, -1);
    Test.assertEqual(client.serviceCallbacks.size(), 4);
    Test.assert(second.result == null);
    Test.assert(second.error == null);
    return true;
}

(:test)
function cancellingClearsTheQueueTheErrorAndTheSlotTogether(logger as Test.Logger) as Boolean {
    // Cancels with a change genuinely occupying the slot (mid-retry, not yet
    // exhausted, so lastError has nothing to do with why the slot later reads
    // as free) and another genuinely still queued — not an empty queue and a
    // free slot that arrived on their own from an already-exhausted run.
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));
    client.fireServiceFailureAt(0, -1);

    client.cancelAll();

    Test.assert(client.lastError() == null);

    // The second tap was still queued, never posted, when cancelAll ran, so
    // it is discarded rather than merely delayed: index 1 is the first
    // change's own stale reissue, a reply to an already-cancelled request,
    // and must reach nobody rather than resolve the second tap's callback.
    client.fireServiceSuccessAt(1);
    Test.assert(second.result == null);
    Test.assert(second.error == null);

    // The slot is free again: a fresh change fires immediately rather than
    // waiting behind whatever the cancelled run left outstanding.
    client.queueLightToggle("light.c", new ResultCapture().method(:onResult));
    Test.assertEqual(client.serviceCallbacks.size(), 3);
    return true;
}

(:test)
function aRefreshWhereOneTargetFailsNeverStampsCompletion(logger as Test.Logger) as Boolean {
    // Completed is a property of the whole refresh, not of one target: the
    // first target succeeding, the second exhausting its retries, and the
    // third succeeding still lands the refresh — but it must not stamp, since
    // lights landing while sensors failed must not look like an up-to-date
    // refresh.
    Application.Storage.clearValues();
    Webhook.setId("some-id");
    var client = new MockHaClient();
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.fireServiceSuccessAt(0);
    client.fireServiceFailureAt(1, -1);
    client.fireServiceFailureAt(2, -1);
    client.fireServiceFailureAt(3, -1);
    client.fireServiceFailureAt(4, -1);
    client.fireServiceSuccessAt(5);

    Test.assertEqual(log.targets.size(), 3);
    Test.assert(client.msSinceLastRefresh() == null);
    return true;
}

