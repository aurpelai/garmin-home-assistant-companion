import Toybox.Application;
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
class SentRequest {
    public var path as String;
    public var body as Dictionary;
    public var handler as ResponseHandler;

    function initialize(path as String, body as Dictionary, handler as ResponseHandler) {
        self.path = path;
        self.body = body;
        self.handler = handler;
    }
}

(:test)
class FakeRequestSender {
    public var sent as Array<SentRequest> = [];
    public var cancellations as Number = 0;

    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        sent.add(new SentRequest(path, body, handler));
    }

    function cancelAll() as Void {
        cancellations++;
    }

    function count() as Number {
        return sent.size();
    }

    function isRegistration(index as Number) as Boolean {
        return (sent[index] as SentRequest).path.find("/registrations") != null;
    }

    function reply(index as Number, code as Number, body as Dictionary or String or Null) as Void {
        (sent[index] as SentRequest).handler.onResponse(code, body);
    }

    function replyLast(code as Number, body as Dictionary or String or Null) as Void {
        reply(sent.size() - 1, code, body);
    }
}

(:test)
class ClientFixture {
    static function clientWith(sender as FakeRequestSender) as HaClient {
        Application.Storage.clearValues();
        return new HaClient(sender);
    }

    // A fetch's raw success payload for an empty home: the render webhook returns
    // the rendered value as a JSON string under its root key.
    static function emptyRenderPayload() as Dictionary {
        return { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{}" };
    }
}

(:test)
class WebhookRequestUnderTest {
    static function of(client as HaClient) as WebhookRequest {
        return new WebhookRequest(client, {}, ResponseType.TEMPLATE_RENDER);
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
    Test.assertEqual((capture.error as RequestError).reason as Number, 401);
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
    Test.assertEqual((missingSection.error as RequestError).reason as Symbol, RequestError.UNREADABLE_BODY);

    var unparsable = new ResultCapture();
    new ResponseHandler(unparsable.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{not json" });

    Test.assert(unparsable.result == null);
    Test.assertEqual((unparsable.error as RequestError).reason as Symbol, RequestError.UNREADABLE_BODY);

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
    Test.assertEqual((capture.error as RequestError).reason as Symbol, RequestError.UNUSABLE_WEBHOOK);
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
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    sender.replyLast(201, { "webhook_id" => "fresh-id" });

    Test.assertEqual(capture.result as String, "fresh-id");

    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));
    Test.assertEqual(sender.count(), 2);
    return true;
}

(:test)
function aSupersededRegistrationsReplyStoresNothing(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    client.cancelAll();

    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));
    sender.reply(0, 201, { "webhook_id" => "abandoned-id" });

    Test.assert(capture.result == null);
    Test.assert(Registration.stored() == null);
    return true;
}

(:test)
function aFailedRegistrationLeavesNoIdBehind(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    sender.reply(0, 400, null);
    sender.reply(1, 400, null);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.BAD_REQUEST);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    Test.assert(Registration.stored() == null);
    Test.assertEqual(sender.count(), 2);
    return true;
}

(:test)
function aRequestInterruptedByADeadWebhookCompletesOnceRegisteringRescuesIt(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    WebhookRequestUnderTest.of(client).attempt(capture.method(:onResult));
    sender.reply(0, 200, null);
    sender.reply(1, 201, { "webhook_id" => "fresh-id" });
    sender.reply(2, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(sender.count(), 3);
    Test.assert(sender.isRegistration(1));
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function anUnusableWebhookThatKeepsComingBackSurfacesAsARequestFailure(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     RequestType.REQUEST).attempt();
    sender.reply(0, 200, null);
    sender.reply(1, 201, { "webhook_id" => "fresh-id" });
    sender.reply(2, 200, null);
    sender.reply(3, 200, null);
    sender.reply(4, 200, null);
    sender.reply(5, 200, null);

    Test.assertEqual(sender.count(), 6);
    Test.assert(sender.isRegistration(1));

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Symbol, RequestError.UNUSABLE_WEBHOOK);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aGenuineNotFoundLeavesTheRegistrationAlone(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("good-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     RequestType.REQUEST).attempt();
    sender.reply(0, HttpStatus.NOT_FOUND, null);
    sender.reply(1, HttpStatus.NOT_FOUND, null);
    sender.reply(2, HttpStatus.NOT_FOUND, null);
    sender.reply(3, HttpStatus.NOT_FOUND, null);

    for (var index = 0; index < sender.count(); index++) {
        Test.assert(!sender.isRegistration(index));
    }
    Test.assertEqual(Registration.stored() as String, "good-id");

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.NOT_FOUND);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aToggleWithNoRegistrationRegistersAndThenGoesOut(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    var capture = new ResultCapture();

    client.queueLightToggle("light.a", capture.method(:onResult));

    Test.assertEqual(sender.count(), 1);
    Test.assert(sender.isRegistration(0));

    sender.reply(0, 201, { "webhook_id" => "fresh-id" });

    Test.assertEqual(sender.count(), 2);

    sender.reply(1, 200, null);

    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerReissuesOnAnyOtherFailureUpToTheThreshold(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     RequestType.REQUEST).attempt();
    sender.reply(0, -1, null);
    sender.reply(1, -1, null);
    sender.reply(2, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(sender.count(), 3);
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerSurfacesTheFailureOnceItsThresholdIsSpent(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     RequestType.REQUEST).attempt();
    sender.reply(0, -1, null);
    sender.reply(1, -1, null);
    sender.reply(2, -1, null);
    sender.reply(3, -1, null);

    Test.assert(capture.result == null);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, -1);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aRegistrationFailureInsideFetchRecoveryStaysARegistrationFailure(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    WebhookRequestUnderTest.of(client).attempt(capture.method(:onResult));
    sender.reply(0, 200, null);
    sender.reply(1, HttpStatus.BAD_REQUEST, null);
    sender.reply(2, HttpStatus.BAD_REQUEST, null);

    Test.assert(sender.isRegistration(1));
    Test.assert(sender.isRegistration(2));

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.BAD_REQUEST);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    return true;
}

(:test)
function registeringClearsTheStaleIdBeforeAskingForAFreshOne(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("stale-id");

    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));

    Test.assertEqual(sender.count(), 1);
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
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", first.method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));

    Test.assertEqual(sender.count(), 1);

    sender.reply(0, 200, null);

    Test.assertEqual(sender.count(), 2);
    Test.assertEqual(first.result as Boolean, true);
    Test.assert(client.hasOutstandingChanges());

    sender.reply(1, 200, null);

    Test.assertEqual(second.result as Boolean, true);
    Test.assert(!client.hasOutstandingChanges());
    return true;
}

(:test)
function changesGoOutBeforeFetches(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));

    sender.reply(0, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(log.targets.size(), 1);
    Test.assert(client.hasOutstandingChanges());

    sender.reply(1, 200, null);

    Test.assert(!client.hasOutstandingChanges());
    Test.assertEqual(log.targets.size(), 1);
    return true;
}

(:test)
function aRefreshTriggeredWhileOneIsIncompleteIsDropped(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.refresh(log.method(:onTarget));

    sender.reply(0, 200, ClientFixture.emptyRenderPayload());
    sender.reply(1, 200, ClientFixture.emptyRenderPayload());
    sender.reply(2, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(sender.count(), 3);
    Test.assertEqual(log.targets.size(), 3);
    Test.assert(!client.isRefreshing());
    return true;
}

(:test)
function aReplyDoesNotStartARefreshWhileChangesAreQueued(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
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
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueLightToggle("light.a", first.method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));

    sender.reply(0, -1, null);
    sender.reply(1, -1, null);
    sender.reply(2, -1, null);

    Test.assertEqual(sender.count(), 4);
    Test.assert(first.error == null);
    Test.assert(second.result == null);
    Test.assert(second.error == null);

    sender.reply(3, -1, null);

    Test.assertEqual((first.error as RequestError).reason as Number, -1);
    Test.assertEqual(sender.count(), 4);
    Test.assert(!client.hasOutstandingChanges());
    Test.assert(second.result == null);
    Test.assert(second.error == null);
    return true;
}

(:test)
function cancellingClearsTheQueueAndTheSlotTogether(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var second = new ResultCapture();

    client.queueLightToggle("light.a", new ResultCapture().method(:onResult));
    client.queueLightToggle("light.b", second.method(:onResult));
    sender.reply(0, -1, null);

    client.cancelAll();

    Test.assert(!client.hasOutstandingChanges());

    sender.reply(1, 200, null);

    Test.assert(second.result == null);
    Test.assert(second.error == null);

    client.queueLightToggle("light.c", new ResultCapture().method(:onResult));

    Test.assertEqual(sender.count(), 3);
    return true;
}

(:test)
function aRefreshWhereOneTargetFailsNeverStampsCompletion(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    sender.reply(0, 200, ClientFixture.emptyRenderPayload());
    sender.reply(1, -1, null);
    sender.reply(2, -1, null);
    sender.reply(3, -1, null);
    sender.reply(4, -1, null);
    sender.reply(5, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(log.targets.size(), 3);

    Test.assertEqual((client.refreshError() as RequestError).reason as Number, -1);
    Test.assert(!client.hasEverRefreshed());
    Test.assert(client.msSinceLastRefresh() == null);
    return true;
}

(:test)
function aRefreshKeepsTheFirstErrorNotTheLast(logger as Test.Logger) as Boolean {
    var sender = new FakeRequestSender();
    var client = ClientFixture.clientWith(sender);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));

    for (var index = 0; index < 4; index++) {
        sender.reply(index, 401, null);
    }
    for (var index = 4; index < 8; index++) {
        sender.reply(index, -1, null);
    }
    sender.reply(8, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(log.targets.size(), 3);
    Test.assertEqual((client.refreshError() as RequestError).reason as Number, 401);
    return true;
}
