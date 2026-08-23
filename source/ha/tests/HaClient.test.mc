import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// Mirrors the key HaClient keeps its registration under, so that key stays
// private to the client rather than gaining a setter only tests would call.
// A class, not a bare function: the test runner collects annotated functions
// as test cases.
(:test)
class Registration {
    static function seed(webhookId as String) as Void {
        Application.Storage.setValue("webhookId", webhookId);
    }

    static function stored() as String? {
        return Application.Storage.getValue("webhookId") as String?;
    }
}

// Captures each entry point's callback instead of making a web request, so a
// test can fire success or failure synchronously.
(:test)
class MockHaClient extends HaClient {
    private var _registerCallback as Method?;

    // A list, not a single slot, so a test can answer an earlier in-flight post
    // after a later one began — a reissue and a stale reply both need that.
    public var webhookCallbacks as Array<Method> = [];

    // A single slot can't distinguish "never registered" from "registered
    // once", so this counts the calls.
    public var registerCount as Number;

    function initialize() {
        HaClient.initialize();
        registerCount = 0;
    }

    // Stands in for any request the retry manager reissues: what those tests
    // pin is the reissue, not which request happened to be the vehicle.
    function fetchOnce(callback as Method) as Void {
        webhookCallbacks.add(callback);
    }

    function attemptRegistration(callback as Method) as Void {
        _registerCallback = callback;
        registerCount++;
    }

    function attemptRequest(body as Dictionary, callback as Method, responseType as Symbol,
                            responseContentType as Communications.HttpResponseContentType) as Void {
        webhookCallbacks.add(callback);
    }

    function fetchCount() as Number {
        return webhookCallbacks.size();
    }

    function fireFetchSuccess(payload as Dictionary) as Void {
        fireSuccessAt(webhookCallbacks.size() - 1, payload);
    }

    function fireFetchFailure(reason as Object) as Void {
        fireFailureAt(webhookCallbacks.size() - 1, reason);
    }

    function fireSuccessAt(index as Number, result as Object) as Void {
        webhookCallbacks[index].invoke(result, null);
    }

    function fireFailureAt(index as Number, reason as Object) as Void {
        webhookCallbacks[index].invoke(null, reason);
    }

    // Persists the fresh id as the real client's registration reply does, since
    // the request reissued behind this reply reads it back from storage.
    function fireRegisterSuccess(webhookId as String) as Void {
        Registration.seed(webhookId);
        (_registerCallback as Method).invoke(webhookId, null);
    }

    function fireRegisterFailure(reason as Object) as Void {
        (_registerCallback as Method).invoke(null, reason);
    }
}

// Overrides only the transport, so registering, onRegistrationReply() and the
// missing-id refusal in attemptRequest all run for real: what these tests pin is
// HaClient's own handling of the stored id, not a mock's imitation of it.
(:test)
class RegisteringHaClient extends HaClient {
    public var postCount as Number = 0;

    // A list, not a single slot, so a test can answer an abandoned request
    // after a later one has already been posted.
    private var _postedHandlers as Array<ResponseHandler> = [];

    function initialize() {
        HaClient.initialize();
    }

    function post(path as String, body as Dictionary, handler as ResponseHandler,
                  responseContentType as Communications.HttpResponseContentType) as Void {
        _postedHandlers.add(handler);
        postCount++;
    }

    function fireResponse(code as Number, body as Dictionary or String or Null) as Void {
        fireResponseAt(_postedHandlers.size() - 1, code, body);
    }

    function fireResponseAt(index as Number, code as Number,
                            body as Dictionary or String or Null) as Void {
        _postedHandlers[index].onResponse(code, body);
    }
}

// The vehicle for every recovery test: a webhook post is the only request that
// can meet an unusable id, so recovery is only reachable through one.
(:test)
class WebhookRequestUnderTest {
    static function of(client as HaClient) as WebhookRequest {
        return new WebhookRequest(client, {}, ResponseType.TEMPLATE_RENDER,
                                  Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON);
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
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER);

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
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER);

    handler.onResponse(200, {
        ResponseType.TEMPLATE_RENDER_ROOT_KEY => { "lights" => { "light.a" => { "state" => true } } }
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
    new ResponseHandler(missingSection.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, {});

    Test.assert(missingSection.result == null);
    Test.assertEqual(missingSection.error as Symbol, RequestError.UNREADABLE_BODY);

    var unparsable = new ResultCapture();
    new ResponseHandler(unparsable.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{not json" });

    Test.assert(unparsable.result == null);
    Test.assertEqual(unparsable.error as Symbol, RequestError.UNREADABLE_BODY);

    // A home that genuinely rendered empty still reads as a success: emptiness
    // is the info view's finding, not the error path's.
    var empty = new ResultCapture();
    new ResponseHandler(empty.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{}" });

    Test.assert(empty.result instanceof Dictionary);
    Test.assert(empty.error == null);
    return true;
}

(:test)
function aDeadWebhooksEmptyBodyIsUnusableRatherThanUnreadable(logger as Test.Logger) as Boolean {
    // A gone webhook answers 200 with an empty body, so the reply is not the
    // rendered envelope at all. That is the id being gone rather than a render
    // that could not be read.
    var capture = new ResultCapture();
    new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, null);

    Test.assert(capture.result == null);
    Test.assertEqual(capture.error as Symbol, RequestError.UNUSABLE_WEBHOOK);
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
function aSuccessfulRegistrationPersistsTheIdForLaterRequests(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new RegisteringHaClient();
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    client.fireResponse(201, { "webhook_id" => "fresh-id" });

    Test.assertEqual(capture.result as String, "fresh-id");

    // The stored id is what postTemplate reads back: a second post reaching
    // the transport, rather than the local 404 an absent id would produce,
    // is what proves onRegistrationReply actually persisted it.
    client.postTemplate("{{ 1 }}", new ResultCapture().method(:onResult));
    Test.assertEqual(client.postCount, 2);
    return true;
}

(:test)
function aSupersededRegistrationsReplyStoresNothing(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new RegisteringHaClient();
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    client.cancelAll();

    // The lazy re-register refills the callback slot, so the abandoned reply
    // below arrives to a live-looking client: without the epoch it would
    // persist the id the cancelled registration was issued for.
    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));
    client.fireResponseAt(0, 201, { "webhook_id" => "abandoned-id" });

    Test.assert(capture.result == null);
    Test.assert(Registration.stored() == null);
    return true;
}

(:test)
function aFailedRegistrationLeavesNoIdBehind(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new RegisteringHaClient();
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    client.fireResponse(400, null);
    client.fireResponseAt(1, 400, null);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.BAD_REQUEST);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    Test.assert(Registration.stored() == null);
    Test.assertEqual(client.postCount, 2);
    return true;
}

(:test)
function aRequestInterruptedByADeadWebhookCompletesOnceRegisteringRescuesIt(logger as Test.Logger) as Boolean {
    // Recovery is not merely registering again: the request the user asked for
    // is reissued behind the fresh id and its result reaches the caller, so a
    // registration that expired mid-flight never surfaces at all.
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    WebhookRequestUnderTest.of(client).attempt(capture.method(:onResult));
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchSuccess({} as Dictionary);

    Test.assertEqual(client.fetchCount(), 2);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function anUnusableWebhookThatKeepsComingBackSurfacesAsARequestFailure(logger as Test.Logger) as Boolean {
    // The registration having succeeded is why the failure is the request's
    // rather than the registration's: a fresh id that is refused the moment it
    // was issued says nothing is wrong with registering.
    Application.Storage.clearValues();
    var client = new MockHaClient();
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     RequestType.REQUEST).attempt();
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);
    client.fireRegisterSuccess("fresh-id");
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);

    // Recovery is spent once, on the first refusal, and never again: the four
    // posts the request budget pays for plus the one the fresh id bought.
    Test.assertEqual(client.fetchCount(), 5);
    Test.assertEqual(client.registerCount, 1);
    Test.assert(capture.result == null);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Symbol, RequestError.UNUSABLE_WEBHOOK);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aGenuineNotFoundLeavesTheRegistrationAlone(logger as Test.Logger) as Boolean {
    // A mistyped base URL answers 404 from an address that has nothing behind
    // it. Reading that as the webhook having died would throw away a working
    // registration and register again against the same wrong address.
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("good-id");
    var capture = new ResultCapture();

    new RetryManager(client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailure(HttpStatus.NOT_FOUND);
    client.fireFetchFailure(HttpStatus.NOT_FOUND);
    client.fireFetchFailure(HttpStatus.NOT_FOUND);
    client.fireFetchFailure(HttpStatus.NOT_FOUND);

    Test.assertEqual(client.registerCount, 0);
    Test.assertEqual(Registration.stored() as String, "good-id");

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.NOT_FOUND);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aToggleWithNoRegistrationRegistersAndThenGoesOut(logger as Test.Logger) as Boolean {
    // An unregistered client refuses the toggle locally, before it reaches the
    // wire, so registering is what lets the first post happen at all: the
    // registration is the only thing on the wire until it answers.
    Application.Storage.clearValues();
    var client = new RegisteringHaClient();
    var capture = new ResultCapture();

    new ServiceCall(client, "toggle", "entity_id", "light.a").attempt(capture.method(:onResult));

    Test.assertEqual(client.postCount, 1);

    client.fireResponse(201, { "webhook_id" => "fresh-id" });

    Test.assertEqual(client.postCount, 2);

    client.fireResponseAt(1, 200, null);

    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerReissuesOnAnyOtherFailureUpToTheThreshold(logger as Test.Logger) as Boolean {
    // Every reason is retried, not just an invalid webhook id: nothing
    // classifies a failure, so an ordinary transport error is reissued too.
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
    var capture = new ResultCapture();

    new RetryManager(client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailure(-1);
    client.fireFetchFailure(-1);
    client.fireFetchSuccess({} as Dictionary);

    Test.assertEqual(client.fetchCount(), 3);
    Test.assertEqual(client.registerCount, 0);
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerSurfacesTheFailureOnceItsThresholdIsSpent(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
    var capture = new ResultCapture();

    new RetryManager(client.method(:fetchOnce), capture.method(:onResult), RequestType.REQUEST).attempt();
    client.fireFetchFailure(-1);
    client.fireFetchFailure(-1);
    client.fireFetchFailure(-1);
    client.fireFetchFailure(-1);

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
    var client = new MockHaClient();
    var capture = new ResultCapture();

    WebhookRequestUnderTest.of(client).attempt(capture.method(:onResult));
    client.fireFetchFailure(RequestError.UNUSABLE_WEBHOOK);
    client.fireRegisterFailure(HttpStatus.BAD_REQUEST);
    client.fireRegisterFailure(HttpStatus.BAD_REQUEST);

    Test.assertEqual(client.registerCount, 2);
    Test.assertEqual(client.fetchCount(), 1);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.BAD_REQUEST);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    return true;
}

(:test)
function registeringClearsTheStaleIdBeforeAskingForAFreshOne(logger as Test.Logger) as Boolean {
    // A registration that never answers must not leave the dead id behind for
    // the next request to post against, so the clear lands before the request
    // goes out rather than on its reply.
    Application.Storage.clearValues();
    Registration.seed("stale-id");
    var client = new RegisteringHaClient();

    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));

    Test.assertEqual(client.postCount, 1);
    Test.assert(Registration.stored() == null);
    return true;
}

// Both a refresh target and a queued change reach the wire as a webhook post,
// so webhookCallbacks is the one seam every test below drives, whichever kind
// fired it. A registration is seeded first so a request does not itself fail as
// unusable, which is what the client answers for a missing id.

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
    var client = new MockHaClient();
    Registration.seed("some-id");
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", first.method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));

    // The first tap occupies the slot; the second is still queued rather than
    // discarded, so it goes out only once the first settles.
    Test.assertEqual(client.fetchCount(), 1);

    client.fireSuccessAt(0, true);

    Test.assertEqual(client.fetchCount(), 2);
    Test.assertEqual(first.result as Boolean, true);
    Test.assert(client.hasOutstandingChanges());

    client.fireSuccessAt(1, true);

    Test.assertEqual(second.result as Boolean, true);
    Test.assert(!client.hasOutstandingChanges());
    return true;
}

(:test)
function changesGoOutBeforeFetches(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));

    // The refresh's first target already occupies the slot when the toggle is
    // queued; once it settles, the queued change goes out ahead of the
    // refresh's next target, which is still waiting.
    client.fireSuccessAt(0, {} as Dictionary);

    Test.assertEqual(log.targets.size(), 1);
    Test.assert(client.hasOutstandingChanges());

    client.fireSuccessAt(1, true);

    Test.assert(!client.hasOutstandingChanges());
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
    var client = new MockHaClient();
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.refresh(log.method(:onTarget));

    client.fireSuccessAt(0, {} as Dictionary);
    client.fireSuccessAt(1, {} as Dictionary);
    client.fireSuccessAt(2, {} as Dictionary);

    Test.assertEqual(client.fetchCount(), 3);
    Test.assertEqual(log.targets.size(), 3);
    Test.assert(!client.isRefreshing());
    return true;
}

(:test)
function aReplyDoesNotStartARefreshWhileChangesAreQueued(logger as Test.Logger) as Boolean {
    // Simulates the coordinator asking for a refresh right after a toggle's
    // own reply, with a second toggle still queued behind it: the refresh
    // trigger must be dropped, since converging against server truth is
    // pointless when more changes are about to be posted.
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
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
    var client = new MockHaClient();
    Registration.seed("some-id");
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", first.method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));

    // One failure is a hypothesis, not a verdict: RetryManager reissues the
    // first toggle on its own (indices 1, 2, 3 below are its own reissues),
    // and the second tap must still be waiting in the queue throughout —
    // untouched by any of them.
    client.fireFailureAt(0, -1);
    client.fireFailureAt(1, -1);
    client.fireFailureAt(2, -1);

    Test.assertEqual(client.fetchCount(), 4);
    Test.assert(first.error == null);
    Test.assert(second.result == null);
    Test.assert(second.error == null);

    // The fourth failure exhausts RetryManager's threshold, which is what
    // finally drains the second tap: it is discarded, not fired, and its
    // callback is never invoked — one signal for one cause, not one per
    // queued change.
    client.fireFailureAt(3, -1);

    Test.assertEqual((first.error as RequestError).reason as Number, -1);
    Test.assertEqual(client.fetchCount(), 4);
    Test.assert(!client.hasOutstandingChanges());
    Test.assert(second.result == null);
    Test.assert(second.error == null);
    return true;
}

(:test)
function cancellingClearsTheQueueAndTheSlotTogether(logger as Test.Logger) as Boolean {
    // Cancels with a change genuinely occupying the slot (mid-retry, not yet
    // exhausted, so the slot later reading as free is cancelAll's doing rather
    // than a threshold spending itself) and another genuinely still queued —
    // not an empty queue and a free slot that arrived on their own from an
    // already-exhausted run.
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
    var second = new ResultCapture();

    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));
    client.fireFailureAt(0, -1);

    client.cancelAll();

    Test.assert(!client.hasOutstandingChanges());

    // The second tap was still queued, never posted, when cancelAll ran, so
    // it is discarded rather than merely delayed: index 1 is the first
    // change's own stale reissue, a reply to an already-cancelled request,
    // and must reach nobody rather than resolve the second tap's callback.
    client.fireSuccessAt(1, true);

    Test.assert(second.result == null);
    Test.assert(second.error == null);

    // The slot is free again: a fresh change fires immediately rather than
    // waiting behind whatever the cancelled run left outstanding.
    client.queueLightToggle("light.c", new ResultCapture().method(:onResult));

    Test.assertEqual(client.fetchCount(), 3);
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
    var client = new MockHaClient();
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.fireSuccessAt(0, {} as Dictionary);
    client.fireFailureAt(1, -1);
    client.fireFailureAt(2, -1);
    client.fireFailureAt(3, -1);
    client.fireFailureAt(4, -1);
    client.fireSuccessAt(5, {} as Dictionary);

    Test.assertEqual(log.targets.size(), 3);

    // The lost target's own failure survives the target that succeeded after
    // it: were the outcome the last reply's, a refresh ending on a success
    // would read as clean.
    var outcome = client.refreshOutcome();
    Test.assertEqual((outcome.lostTargetTo as RequestError).reason as Number, -1);
    Test.assert(!outcome.everCompleted);
    Test.assert(client.msSinceLastRefresh() == null);
    return true;
}

