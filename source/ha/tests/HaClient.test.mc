import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

(:test)
class Registration {
    static function seed(webhookId as String) as Void {
        Application.Storage.setValue("webhookId", webhookId);
    }

    static function stored() as String? {
        return Application.Storage.getValue("webhookId") as String?;
    }
}

(:test)
class MockHaClient extends HaClient {
    private var _registerCallback as Method?;

    public var webhookCallbacks as Array<Method> = [];
    public var registerCount as Number;

    function initialize() {
        HaClient.initialize();
        registerCount = 0;
    }

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

    function fireRegisterSuccess(webhookId as String) as Void {
        Registration.seed(webhookId);
        (_registerCallback as Method).invoke(webhookId, null);
    }

    function fireRegisterFailure(reason as Object) as Void {
        (_registerCallback as Method).invoke(null, reason);
    }
}

(:test)
class RegisteringHaClient extends HaClient {
    public var postCount as Number = 0;
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

(:test)
class WebhookRequestUnderTest {
    static function of(client as HaClient) as WebhookRequest {
        return new WebhookRequest(client, {}, ResponseType.TEMPLATE_RENDER,
                                  Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON);
    }
}

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
    var missingSection = new ResultCapture();
    new ResponseHandler(missingSection.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, {});

    Test.assert(missingSection.result == null);
    Test.assertEqual(missingSection.error as Symbol, RequestError.UNREADABLE_BODY);

    var unparsable = new ResultCapture();
    new ResponseHandler(unparsable.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{not json" });

    Test.assert(unparsable.result == null);
    Test.assertEqual(unparsable.error as Symbol, RequestError.UNREADABLE_BODY);

    var empty = new ResultCapture();
    new ResponseHandler(empty.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{}" });

    Test.assert(empty.result instanceof Dictionary);
    Test.assert(empty.error == null);
    return true;
}

(:test)
function aDeadWebhooksEmptyBodyIsUnusableRatherThanUnreadable(logger as Test.Logger) as Boolean {
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

    // UNVERIFIED: HA returns 201 Created for /api/mobile_app/registrations.
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

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, -1);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aRegistrationFailureInsideFetchRecoveryStaysARegistrationFailure(logger as Test.Logger) as Boolean {
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
    Application.Storage.clearValues();
    Registration.seed("stale-id");
    var client = new RegisteringHaClient();

    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));

    Test.assertEqual(client.postCount, 1);
    Test.assert(Registration.stored() == null);
    return true;
}

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

    client.fireFailureAt(0, -1);
    client.fireFailureAt(1, -1);
    client.fireFailureAt(2, -1);

    Test.assertEqual(client.fetchCount(), 4);
    Test.assert(first.error == null);
    Test.assert(second.result == null);
    Test.assert(second.error == null);

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
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
    var second = new ResultCapture();

    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));
    client.fireFailureAt(0, -1);

    client.cancelAll();

    Test.assert(!client.hasOutstandingChanges());

    client.fireSuccessAt(1, true);

    Test.assert(second.result == null);
    Test.assert(second.error == null);

    client.queueLightToggle("light.c", new ResultCapture().method(:onResult));

    Test.assertEqual(client.fetchCount(), 3);
    return true;
}

(:test)
function aRefreshWhereOneTargetFailsNeverStampsCompletion(logger as Test.Logger) as Boolean {
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

    var result = client.refreshResult();
    Test.assertEqual((result.error as RequestError).reason as Number, -1);
    Test.assert(!result.hasEverCompleted);
    Test.assert(client.msSinceLastRefresh() == null);
    return true;
}

(:test)
function aRefreshKeepsTheFirstErrorNotTheLast(logger as Test.Logger) as Boolean {
    Application.Storage.clearValues();
    var client = new MockHaClient();
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));

    for (var index = 0; index < 4; index++) {
        client.fireFailureAt(index, 401);
    }
    for (var index = 4; index < 8; index++) {
        client.fireFailureAt(index, -1);
    }
    client.fireSuccessAt(8, {} as Dictionary);

    Test.assertEqual(log.targets.size(), 3);
    Test.assertEqual((client.refreshResult().error as RequestError).reason as Number, 401);
    return true;
}

