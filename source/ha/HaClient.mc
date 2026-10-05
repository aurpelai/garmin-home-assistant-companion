import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

class HaClient {
    // UNVERIFIED: the device can't introspect its real model/OS, so every
    // install registers under these same constants.
    private const DEVICE_ID = "companion_for_home_assistant";
    private const APP_ID = "companion_for_home_assistant";
    private const APP_NAME = "Companion For Home Assistant";
    private const APP_VERSION = "0.13.1";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    private const STALE_AFTER_MS = 60 * 1000;

    private var _flowController as FlowController;
    private var _scheduler as Scheduler;
    private var _refreshManager as RefreshManager;

    private var _onRefreshTarget as Method or Null;
    private var _isFullRefreshPending as Boolean;
    private var _lastRefreshCompletedAt as Number or Null;
    private var _registrationCallbacks as Array<Method>;
    private var _registrationEpoch as Number;

    function initialize(flowController as FlowController, scheduler as Scheduler) {
        _flowController = flowController;
        _scheduler = scheduler;
        _refreshManager = new RefreshManager(method(:buildTemplateRenderRequest), method(:onTargetSettled), scheduler);
        _onRefreshTarget = null;
        _isFullRefreshPending = false;
        _lastRefreshCompletedAt = null;
        _registrationCallbacks = [];
        _registrationEpoch = 0;
    }

    function onTargetSettled(target as Symbol, result as Object or Null, isRefreshSettled as Boolean) as Void {
        if (isRefreshSettled) {
            if (_isFullRefreshPending && getErrors().size() == 0) {
                _lastRefreshCompletedAt = System.getTimer();
            }

            _isFullRefreshPending = false;
        }

        var onTarget = _onRefreshTarget;

        if (onTarget != null) {
            onTarget.invoke(target, result, isRefreshSettled);
        }
    }

    function onRegistrationSettled(epoch as Number, webhookId as String or Null,
                                   error as RequestError or Null) as Void {
        if (epoch != _registrationEpoch) {
            return;
        }

        if (error == null) {
            setRegistration(webhookId as String);
        }

        var callbacks = _registrationCallbacks;
        _registrationCallbacks = [];

        for (var i = 0; i < callbacks.size(); i++) {
            callbacks[i].invoke(webhookId, error);
        }
    }

    function isRefreshDue() as Boolean {
        if (_refreshManager.isFetching()) {
            return false;
        }

        var completedAt = _lastRefreshCompletedAt;

        return completedAt == null || System.getTimer() - completedAt > STALE_AFTER_MS;
    }

    function getErrors() as Array<RequestError> {
        return _refreshManager.getErrors();
    }

    function getRegistration() as String or Null {
        return Application.Storage.getValue(Webhook.REGISTRATION_KEY) as String or Null;
    }

    function refresh(onTarget as Method) as Void {
        _onRefreshTarget = onTarget;
        _isFullRefreshPending = true;
        _refreshManager.fetchAll();
    }

    function callToggleService(entityId as String, callback as Method) as Void {
        callService(Entity.parseDomain(entityId), "toggle", { "entity_id" => entityId }, callback);
    }

    function callLightServiceInAreas(areaIds as Array<String>, service as String, callback as Method) as Void {
        callService(Domain.LIGHT, service, { "area_id" => areaIds }, callback);
    }

    function callAttributeService(domain as String, service as String, entityId as String, field as String,
                                  value as Object, callback as Method) as Void {
        callService(domain, service, { "entity_id" => entityId, field => value }, callback);
    }

    function registerWithHomeAssistant(callback as Method) as Void {
        _registrationCallbacks.add(callback);

        if (_registrationCallbacks.size() > 1) {
            return;
        }

        discardRegistration();
        new RetryManager(method(:attemptRegistration),
            new EpochHandler(method(:onRegistrationSettled), _registrationEpoch).method(:onSettled),
            _scheduler, RequestType.REGISTRATION).attempt();
    }

    function cancelAll() as Void {
        var callbacks = _registrationCallbacks;
        _registrationEpoch++;
        _registrationCallbacks = [];
        _refreshManager.reset();
        _flowController.cancelAll();
        _scheduler.cancel();

        for (var i = 0; i < callbacks.size(); i++) {
            callbacks[i].invoke(null, new RequestError(RequestError.CANCELLED, null));
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
        _flowController.post(path, body, handler.method(:onResponse));
    }

    private function callService(domain as String, service as String, serviceData as Dictionary,
                                 callback as Method) as Void {
        var handler = new ServiceCallHandler(callback, _refreshManager, domain);
        handler.invalidateTarget();
        new RetryManager(buildServiceCallRequest(domain, service, serviceData), handler.method(:onSettled),
            _scheduler, RequestType.REQUEST).attempt();
    }

    private function buildServiceCallRequest(domain as String, service as String,
                                             serviceData as Dictionary) as Method {
        var body = {
            "type" => "call_service",
            "data" => {
                "domain" => domain,
                "service" => service,
                "service_data" => serviceData
            }
        };

        return new WebhookRequest(self, body, ResponseType.SERVICE_CALL).method(:attempt);
    }

    private function setRegistration(webhookId as String) as Void {
        Application.Storage.setValue(Webhook.REGISTRATION_KEY, webhookId);
    }
}
