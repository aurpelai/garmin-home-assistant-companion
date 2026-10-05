import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// The only object that talks to Home Assistant, and the only one that decides
// when. Knows no domain types: a fetch reply hands out a raw payload for the
// caller to parse.
class HaClient {
    // UNVERIFIED: the device can't introspect its real model/OS, so every
    // install registers under these same constants.
    private const DEVICE_ID = "companion_for_home_assistant";
    private const APP_ID = "companion_for_home_assistant";
    private const APP_NAME = "Companion For Home Assistant";
    private const APP_VERSION = "0.13.0";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    private const STALE_AFTER_MS = 60 * 1000;

    private var _gateway as RequestGateway;
    private var _scheduler as Scheduler;
    private var _refreshManager as RefreshManager;

    private var _onRefreshTarget as Method or Null;
    private var _isFullRefreshPending as Boolean;
    private var _lastRefreshCompletedAt as Number or Null;
    private var _registrationWaiters as Array<Method>;
    private var _registrationStamp as Number;

    function initialize(gateway as RequestGateway, scheduler as Scheduler) {
        _gateway = gateway;
        _scheduler = scheduler;
        _refreshManager = new RefreshManager(method(:buildTemplateRenderRequest), method(:onTargetSettled), scheduler);
        _onRefreshTarget = null;
        _isFullRefreshPending = false;
        _lastRefreshCompletedAt = null;
        _registrationWaiters = [];
        _registrationStamp = 0;
    }

    function onTargetSettled(target as Symbol, result as Object or Null, isSettled as Boolean) as Void {
        if (isSettled) {
            if (_isFullRefreshPending && getErrors().size() == 0) {
                _lastRefreshCompletedAt = System.getTimer();
            }

            _isFullRefreshPending = false;
        }

        var onTarget = _onRefreshTarget;

        if (onTarget != null) {
            onTarget.invoke(target, result, isSettled);
        }
    }

    function onRegistrationSettled(stamp as Number, webhookId as String or Null,
                                   error as RequestError or Null) as Void {
        if (stamp != _registrationStamp) {
            return;
        }

        if (error == null) {
            setRegistration(webhookId as String);
        }

        var waiters = _registrationWaiters;
        _registrationWaiters = [];

        for (var i = 0; i < waiters.size(); i++) {
            waiters[i].invoke(webhookId, error);
        }
    }

    function isRefreshDue() as Boolean {
        var completedAt = _lastRefreshCompletedAt;

        return !_refreshManager.isFetching()
            && (completedAt == null || System.getTimer() - completedAt > STALE_AFTER_MS);
    }

    function getErrors() as Array<RequestError> {
        return _refreshManager.getErrors();
    }

    function refresh(onTarget as Method) as Void {
        _onRefreshTarget = onTarget;
        _isFullRefreshPending = true;
        _refreshManager.fetchAll();
    }

    function sendToggle(entityId as String, callback as Method) as Void {
        var domain = Entity.parseDomain(entityId);
        sendChange(domain, buildServiceCallRequest(domain, "toggle", "entity_id", entityId), callback);
    }

    function sendLightsInAreas(areaIds as Array<String>, service as String, callback as Method) as Void {
        sendChange(Domain.LIGHT, buildServiceCallRequest(Domain.LIGHT, service, "area_id", areaIds), callback);
    }

    function sendAttribute(domain as String, service as String, entityId as String, field as String,
                           value as Object, callback as Method) as Void {
        sendChange(domain, buildAttributeRequest(domain, service, entityId, field, value), callback);
    }

    function registerWithHomeAssistant(callback as Method) as Void {
        _registrationWaiters.add(callback);

        if (_registrationWaiters.size() > 1) {
            return;
        }

        discardRegistration();
        new RetryManager(method(:attemptRegistration),
            new StampHandler(method(:onRegistrationSettled), _registrationStamp).method(:onSettled),
            _scheduler, RequestType.REGISTRATION).attempt();
    }

    function cancelAll() as Void {
        var waiters = _registrationWaiters;
        _registrationStamp++;
        _registrationWaiters = [];
        _refreshManager.reset();
        _gateway.cancelAll();
        _scheduler.cancel();

        for (var i = 0; i < waiters.size(); i++) {
            waiters[i].invoke(null, new RequestError(RequestError.CANCELLED, null));
        }
    }

    function attemptRegistration(callback as Method) as Void {
        var body = {
            "device_id" => DEVICE_ID,
            "app_id" => APP_ID,
            "app_name" => APP_NAME,
            "app_version" => APP_VERSION,
            "device_name" => DEVICE_NAME,
            "manufacturer" => MANUFACTURER,
            "model" => MODEL,
            "os_name" => OS_NAME,
            "os_version" => OS_VERSION,
            "supports_encryption" => false,
            "app_data" => {}
        };
        post("/api/mobile_app/registrations", body, new ResponseHandler(callback, ResponseType.REGISTRATION));
    }

    function attemptRequest(webhookId as String or Null, body as Dictionary, callback as Method,
                            responseType as Symbol) as Void {
        if (webhookId == null) {
            callback.invoke(null, new RequestError(RequestError.UNUSABLE_WEBHOOK, null));
            return;
        }

        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, responseType));
    }

    function getRegistration() as String or Null {
        return Application.Storage.getValue(Webhook.REGISTRATION_KEY) as String or Null;
    }

    function discardRegistration() as Void {
        Application.Storage.deleteValue(Webhook.REGISTRATION_KEY);
    }

    function buildTemplateRenderRequest(target as Symbol) as Method {
        var body = {
            "type" => "render_template",
            "data" => {
                ResponseType.TEMPLATE_RENDER_ROOT_KEY => {
                    "template" => HaTemplate.resolve(target, VisibilityStore.getHiddenFloors(),
                        VisibilityStore.getHiddenAreas(), VisibilityStore.getIncludedLabels().keys() as Array<String>)
                }
            }
        };

        return new WebhookRequest(self, body, ResponseType.TEMPLATE_RENDER).method(:attempt);
    }

    private function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        _gateway.post(path, body, handler.method(:onResponse));
    }

    private function sendChange(domain as String, request as Method, callback as Method) as Void {
        var target = domain.equals(Domain.FAN) ? FetchTarget.FANS : FetchTarget.LIGHTS;
        _refreshManager.invalidate(target);
        new RetryManager(request, new ChangeHandler(callback, _refreshManager, target).method(:onSettled),
            _scheduler, RequestType.REQUEST).attempt();
    }

    private function buildServiceCallRequest(domain as String, service as String, targetKey as String,
                                             target as String or Array<String>) as Method {
        var body = {
            "type" => "call_service",
            "data" => {
                "domain" => domain,
                "service" => service,
                "service_data" => {
                    targetKey => target
                }
            }
        };

        return new WebhookRequest(self, body, ResponseType.SERVICE_CALL).method(:attempt);
    }

    private function buildAttributeRequest(domain as String, service as String, entityId as String,
                                           field as String, value as Object) as Method {
        var body = {
            "type" => "call_service",
            "data" => {
                "domain" => domain,
                "service" => service,
                "service_data" => {
                    "entity_id" => entityId,
                    field => value
                }
            }
        };

        return new WebhookRequest(self, body, ResponseType.SERVICE_CALL).method(:attempt);
    }

    private function setRegistration(webhookId as String) as Void {
        Application.Storage.setValue(Webhook.REGISTRATION_KEY, webhookId);
    }
}
