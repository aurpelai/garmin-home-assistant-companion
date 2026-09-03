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
class FakeRequestGateway {
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

// Holds the scheduled retry so a test can run it on demand, standing in for the
// real Scheduler's timer, which never fires inside the test harness.
(:test)
class FakeScheduler {
    private var _pending as Method or Null = null;

    function schedule(action as Method() as Void, delayMs as Number) as Void {
        _pending = action;
    }

    function cancel() as Void {
        _pending = null;
    }

    function runScheduled() as Void {
        var action = _pending;
        _pending = null;
        if (action != null) {
            action.invoke();
        }
    }
}

(:test)
class ClientFixture {
    static function clientWith(gateway as FakeRequestGateway, scheduler as FakeScheduler) as HaClient {
        Application.Storage.clearValues();
        return new HaClient(gateway, scheduler);
    }

    // The render webhook returns the rendered value as a JSON string under its root key.
    static function renderPayload(json as String) as Dictionary {
        return { ResponseType.TEMPLATE_RENDER_ROOT_KEY => json };
    }

    static function emptyRenderPayload() as Dictionary {
        return renderPayload("{}");
    }

    static function sentDomain(gateway as FakeRequestGateway, index as Number) as String {
        return sentServiceData(gateway, index).get("domain") as String;
    }

    static function sentService(gateway as FakeRequestGateway, index as Number) as String {
        return sentServiceData(gateway, index).get("service") as String;
    }

    static function sentField(gateway as FakeRequestGateway, index as Number, field as String) as Object or Null {
        return (sentServiceData(gateway, index).get("service_data") as Dictionary).get(field);
    }

    private static function sentServiceData(gateway as FakeRequestGateway, index as Number) as Dictionary {
        return (gateway.sent[index] as SentRequest).body.get("data") as Dictionary;
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
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    gateway.replyLast(201, { "webhook_id" => "fresh-id" });

    Test.assertEqual(capture.result as String, "fresh-id");

    client.queueToggle("light.a", new ResultCapture().method(:onResult));
    Test.assertEqual(gateway.count(), 2);
    return true;
}

(:test)
function aSupersededRegistrationsReplyStoresNothing(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    client.cancelAll();

    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));
    gateway.reply(0, 201, { "webhook_id" => "abandoned-id" });

    Test.assert(capture.result == null);
    Test.assert(Registration.stored() == null);
    return true;
}

(:test)
function aFailedRegistrationLeavesNoIdBehind(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    var capture = new ResultCapture();

    client.registerWithHomeAssistant(capture.method(:onResult));
    gateway.reply(0, 400, null);
    scheduler.runScheduled();
    gateway.reply(1, 400, null);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.BAD_REQUEST);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    Test.assert(Registration.stored() == null);
    Test.assertEqual(gateway.count(), 2);
    return true;
}

(:test)
function aRequestInterruptedByADeadWebhookCompletesOnceRegisteringRescuesIt(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    WebhookRequestUnderTest.of(client).attempt(capture.method(:onResult));
    gateway.reply(0, 200, null);
    gateway.reply(1, 201, { "webhook_id" => "fresh-id" });
    gateway.reply(2, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(gateway.count(), 3);
    Test.assert(gateway.isRegistration(1));
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function anUnusableWebhookThatKeepsComingBackSurfacesAsARequestFailure(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     scheduler, RequestType.REQUEST).attempt();
    gateway.reply(0, 200, null);
    gateway.reply(1, 201, { "webhook_id" => "fresh-id" });
    gateway.reply(2, 200, null);
    scheduler.runScheduled();
    gateway.reply(3, 200, null);
    scheduler.runScheduled();
    gateway.reply(4, 200, null);
    scheduler.runScheduled();
    gateway.reply(5, 200, null);

    Test.assertEqual(gateway.count(), 6);
    Test.assert(gateway.isRegistration(1));

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Symbol, RequestError.UNUSABLE_WEBHOOK);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aGenuineNotFoundLeavesTheRegistrationAlone(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("good-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     scheduler, RequestType.REQUEST).attempt();
    gateway.reply(0, HttpStatus.NOT_FOUND, null);
    scheduler.runScheduled();
    gateway.reply(1, HttpStatus.NOT_FOUND, null);
    scheduler.runScheduled();
    gateway.reply(2, HttpStatus.NOT_FOUND, null);
    scheduler.runScheduled();
    gateway.reply(3, HttpStatus.NOT_FOUND, null);

    for (var index = 0; index < gateway.count(); index++) {
        Test.assert(!gateway.isRegistration(index));
    }
    Test.assertEqual(Registration.stored() as String, "good-id");

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.NOT_FOUND);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aToggleWithNoRegistrationRegistersAndThenGoesOut(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    var capture = new ResultCapture();

    client.queueToggle("light.a", capture.method(:onResult));

    Test.assertEqual(gateway.count(), 1);
    Test.assert(gateway.isRegistration(0));

    gateway.reply(0, 201, { "webhook_id" => "fresh-id" });

    Test.assertEqual(gateway.count(), 2);

    gateway.reply(1, 200, null);

    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerReissuesOnAnyOtherFailureUpToTheThreshold(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     scheduler, RequestType.REQUEST).attempt();
    gateway.reply(0, -1, null);
    scheduler.runScheduled();
    gateway.reply(1, -1, null);
    scheduler.runScheduled();
    gateway.reply(2, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(gateway.count(), 3);
    Test.assert(capture.result instanceof Dictionary);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function retryManagerSurfacesTheFailureOnceItsThresholdIsSpent(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var capture = new ResultCapture();

    new RetryManager(WebhookRequestUnderTest.of(client).method(:attempt), capture.method(:onResult),
                     scheduler, RequestType.REQUEST).attempt();
    gateway.reply(0, -1, null);
    scheduler.runScheduled();
    gateway.reply(1, -1, null);
    scheduler.runScheduled();
    gateway.reply(2, -1, null);
    scheduler.runScheduled();
    gateway.reply(3, -1, null);

    Test.assert(capture.result == null);

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, -1);
    Test.assertEqual(error.requestType, RequestType.REQUEST);
    return true;
}

(:test)
function aRegistrationFailureInsideFetchRecoveryStaysARegistrationFailure(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("stale-id");
    var capture = new ResultCapture();

    WebhookRequestUnderTest.of(client).attempt(capture.method(:onResult));
    gateway.reply(0, 200, null);
    gateway.reply(1, HttpStatus.BAD_REQUEST, null);
    scheduler.runScheduled();
    gateway.reply(2, HttpStatus.BAD_REQUEST, null);

    Test.assert(gateway.isRegistration(1));
    Test.assert(gateway.isRegistration(2));

    var error = capture.error as RequestError;
    Test.assertEqual(error.reason as Number, HttpStatus.BAD_REQUEST);
    Test.assertEqual(error.requestType, RequestType.REGISTRATION);
    return true;
}

(:test)
function registeringClearsTheStaleIdBeforeAskingForAFreshOne(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("stale-id");

    client.registerWithHomeAssistant(new ResultCapture().method(:onResult));

    Test.assertEqual(gateway.count(), 1);
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
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueToggle("light.a", first.method(:onResult));
    client.queueToggle("light.b", second.method(:onResult));

    Test.assertEqual(gateway.count(), 1);

    gateway.reply(0, 200, null);

    Test.assertEqual(gateway.count(), 2);
    Test.assertEqual(first.result as Boolean, true);
    Test.assert(client.hasOutstandingChanges());

    gateway.reply(1, 200, null);

    Test.assertEqual(second.result as Boolean, true);
    Test.assert(!client.hasOutstandingChanges());
    return true;
}

(:test)
function changesGoOutBeforeFetches(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.queueToggle("light.a", new ResultCapture().method(:onResult));

    gateway.reply(0, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(log.targets.size(), 1);
    Test.assert(client.hasOutstandingChanges());

    gateway.reply(1, 200, null);

    Test.assert(!client.hasOutstandingChanges());
    Test.assertEqual(log.targets.size(), 1);
    return true;
}

(:test)
function aRefreshTriggeredWhileOneIsIncompleteIsDropped(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    client.refresh(log.method(:onTarget));

    gateway.reply(0, 200, ClientFixture.emptyRenderPayload());
    gateway.reply(1, 200, ClientFixture.emptyRenderPayload());
    gateway.reply(2, 200, ClientFixture.emptyRenderPayload());
    gateway.reply(3, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(gateway.count(), 4);
    Test.assertEqual(log.targets.size(), 4);
    Test.assert(!client.isRefreshing());
    return true;
}

(:test)
function aReplyDoesNotStartARefreshWhileChangesAreQueued(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.queueToggle("light.a", new ResultCapture().method(:onResult));
    client.queueToggle("light.b", new ResultCapture().method(:onResult));
    client.refresh(log.method(:onTarget));

    Test.assertEqual(log.targets.size(), 0);
    return true;
}

(:test)
function theQueueDrainsOnlyOnceTheThresholdIsExhausted(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var first = new ResultCapture();
    var second = new ResultCapture();

    client.queueToggle("light.a", first.method(:onResult));
    client.queueToggle("light.b", second.method(:onResult));

    gateway.reply(0, -1, null);
    scheduler.runScheduled();
    gateway.reply(1, -1, null);
    scheduler.runScheduled();
    gateway.reply(2, -1, null);
    scheduler.runScheduled();

    Test.assertEqual(gateway.count(), 4);
    Test.assert(first.error == null);
    Test.assert(second.result == null);
    Test.assert(second.error == null);

    gateway.reply(3, -1, null);

    Test.assertEqual((first.error as RequestError).reason as Number, -1);
    Test.assertEqual(gateway.count(), 4);
    Test.assert(!client.hasOutstandingChanges());
    Test.assert(second.result == null);
    Test.assert(second.error == null);
    return true;
}

(:test)
function cancellingClearsTheQueueAndTheSlotTogether(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var second = new ResultCapture();

    client.queueToggle("light.a", new ResultCapture().method(:onResult));
    client.queueToggle("light.b", second.method(:onResult));
    gateway.reply(0, -1, null);

    client.cancelAll();

    Test.assert(!client.hasOutstandingChanges());

    // The scheduled retry is dropped, so running it posts nothing.
    scheduler.runScheduled();

    Test.assert(second.result == null);
    Test.assert(second.error == null);

    client.queueToggle("light.c", new ResultCapture().method(:onResult));

    Test.assertEqual(gateway.count(), 2);
    return true;
}

(:test)
function aRefreshWhereOneTargetFailsNeverStampsCompletion(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));
    gateway.reply(0, 200, ClientFixture.emptyRenderPayload());
    gateway.reply(1, -1, null);
    scheduler.runScheduled();
    gateway.reply(2, -1, null);
    scheduler.runScheduled();
    gateway.reply(3, -1, null);
    scheduler.runScheduled();
    gateway.reply(4, -1, null);
    gateway.reply(5, 200, ClientFixture.emptyRenderPayload());
    gateway.reply(6, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(log.targets.size(), 4);

    Test.assertEqual((client.getError() as RequestError).reason as Number, -1);
    Test.assert(!client.hasEverRefreshed());
    Test.assert(client.msSinceLastRefresh() == null);
    return true;
}

(:test)
function aRefreshKeepsTheFirstErrorNotTheLast(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");
    var log = new TargetLog();

    client.refresh(log.method(:onTarget));

    for (var index = 0; index < 4; index++) {
        gateway.reply(index, 401, null);
        scheduler.runScheduled();
    }
    for (var index = 4; index < 8; index++) {
        gateway.reply(index, -1, null);
        scheduler.runScheduled();
    }
    gateway.reply(8, 200, ClientFixture.emptyRenderPayload());
    gateway.reply(9, 200, ClientFixture.emptyRenderPayload());

    Test.assertEqual(log.targets.size(), 4);
    Test.assertEqual((client.getError() as RequestError).reason as Number, 401);
    return true;
}

(:test)
function aToggleCallsTheDomainOfTheEntityItTargets(logger as Test.Logger) as Boolean {
    var gateway = new FakeRequestGateway();
    var scheduler = new FakeScheduler();
    var client = ClientFixture.clientWith(gateway, scheduler);
    Registration.seed("some-id");

    client.queueToggle("fan.ceiling", new ResultCapture().method(:onResult));
    gateway.reply(0, 200, null);
    client.queueToggle("light.a", new ResultCapture().method(:onResult));
    gateway.reply(1, 200, null);
    client.queueFloorLights("floor.g", "turn_on", new ResultCapture().method(:onResult));

    Test.assertEqual(ClientFixture.sentDomain(gateway, 0), "fan");
    Test.assertEqual(ClientFixture.sentDomain(gateway, 1), "light");
    Test.assertEqual(ClientFixture.sentDomain(gateway, 2), "light");
    return true;
}
