import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// The only object that talks to Home Assistant, and the only one that decides
// when. Knows no domain types: a fetch reply hands out a raw payload for the
// caller to parse.
//
// UNVERIFIED: Connect IQ allows one outstanding request of any kind — exceeding
// it yields a queue-full transport error — so everything below serialises
// through a single slot that a refresh and a service call compete for.
class HaClient {
    // UNVERIFIED: the device can't introspect its real model/OS, so every
    // install registers under these same constants.
    private const DEVICE_ID = "companion_for_home_assistant";
    private const APP_ID = "companion_for_home_assistant";
    private const APP_NAME = "Companion For Home Assistant";
    private const APP_VERSION = "0.12.1";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    private const REFRESH_TARGETS = [FetchTarget.STRUCTURE, FetchTarget.LIGHTS, FetchTarget.FANS, FetchTarget.SENSORS];
    private const STALE_AFTER_MS = 60 * 1000;

    private var _gateway as RequestGateway;
    private var _scheduler as Scheduler;

    private var _isRequestInFlight as Boolean;
    private var _isChangeInFlight as Boolean;
    private var _changeQueue as Array<QueuedChange>;
    private var _pendingChangeCallback as Method or Null;
    private var _registrationCallback as Method or Null;
    private var _registrationEpoch as Number;
    private var _pendingFetchTargets as Array<Symbol>;
    private var _currentTarget as Symbol or Null;
    private var _onRefreshTarget as Method or Null;
    private var _error as RequestError or Null;
    private var _lastRefreshCompletedAt as Number or Null;

    function initialize(gateway as RequestGateway, scheduler as Scheduler) {
        _gateway = gateway;
        _scheduler = scheduler;
        _isRequestInFlight = false;
        _isChangeInFlight = false;
        _changeQueue = [];
        _pendingChangeCallback = null;
        _registrationCallback = null;
        _registrationEpoch = 0;
        _pendingFetchTargets = [];
        _currentTarget = null;
        _onRefreshTarget = null;
        _error = null;
        _lastRefreshCompletedAt = null;
    }

    function onChangeSettled(result as Object or Null, error as RequestError or Null) as Void {
        _isRequestInFlight = false;
        _isChangeInFlight = false;

        if (_pendingChangeCallback == null) {
            return;
        }

        var callback = _pendingChangeCallback as Method;
        _pendingChangeCallback = null;

        if (error != null) {
            _changeQueue = [];
        }

        callback.invoke(result, error);
        startNextRequest();
    }

    function onTargetSettled(result as Object or Null, error as RequestError or Null) as Void {
        _isRequestInFlight = false;

        if (_currentTarget == null || _onRefreshTarget == null) {
            return;
        }

        var target = _currentTarget as Symbol;
        var onTarget = _onRefreshTarget as Method;

        if (_error == null) {
            _error = error;
        }

        var isLastTarget = !isRefreshing();

        if (isLastTarget && _error == null) {
            _lastRefreshCompletedAt = System.getTimer();
        }

        onTarget.invoke(target, result, isLastTarget);
        startNextRequest();
    }

    function onRegistrationSettled(epoch as Number, webhookId as String or Null,
                                 error as RequestError or Null) as Void {
        if (epoch != _registrationEpoch || _registrationCallback == null) {
            return;
        }

        if (error == null) {
            setRegistration(webhookId as String);
        }

        var callback = _registrationCallback as Method;
        _registrationCallback = null;
        callback.invoke(webhookId, error);
    }

    function isRefreshing() as Boolean {
        return _pendingFetchTargets.size() > 0;
    }

    function hasOutstandingChanges() as Boolean {
        return _changeQueue.size() > 0 || _isChangeInFlight;
    }

    function isRefreshDue() as Boolean {
        var completedAt = _lastRefreshCompletedAt;
        return completedAt == null || System.getTimer() - completedAt > STALE_AFTER_MS;
    }

    function getError() as RequestError or Null {
        return _error;
    }

    function hasEverRefreshed() as Boolean {
        return _lastRefreshCompletedAt != null;
    }

    function refresh(onTarget as Method) as Void {
        if (isRefreshing() || hasOutstandingChanges()) {
            return;
        }

        _pendingFetchTargets = REFRESH_TARGETS.slice(0, null) as Array<Symbol>;
        _error = null;
        _onRefreshTarget = onTarget;
        startNextRequest();
    }

    function queueToggle(entityId as String, callback as Method) as Void {
        queueChange(buildServiceCallRequest(Entity.parseDomain(entityId), "toggle", "entity_id", entityId), callback);
    }

    function queueLightsInAreas(areaIds as Array<String>, service as String, callback as Method) as Void {
        queueChange(buildServiceCallRequest(Domain.LIGHT, service, "area_id", areaIds), callback);
    }

    function queueAttribute(domain as String, service as String, entityId as String, field as String,
                            value as Object, callback as Method) as Void {
        queueChange(buildAttributeRequest(domain, service, entityId, field, value), callback);
    }

    // UNVERIFIED: Connect IQ still delivers a cancelled request's reply, so the
    // callbacks are nulled to drop it.
    function cancelAll() as Void {
        _gateway.cancelAll();
        _scheduler.cancel();
        _changeQueue = [];
        _pendingFetchTargets = [];
        _isRequestInFlight = false;
        _isChangeInFlight = false;
        _pendingChangeCallback = null;
        _registrationCallback = null;
        _registrationEpoch++;
        _currentTarget = null;
        _onRefreshTarget = null;
    }

    function registerWithHomeAssistant(callback as Method) as Void {
        new RetryManager(method(:attemptRegistration), callback, _scheduler, RequestType.REGISTRATION).attempt();
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
        discardRegistration();
        _registrationCallback = callback;
        _registrationEpoch++;
        post("/api/mobile_app/registrations", body,
             new ResponseHandler(new RegistrationHandler(self, _registrationEpoch).method(:onSettled),
                                 ResponseType.REGISTRATION));
    }

    function attemptRequest(body as Dictionary, callback as Method, responseType as Symbol) as Void {
        var webhookId = Application.Storage.getValue(Webhook.REGISTRATION_KEY) as String or Null;

        if (webhookId == null) {
            callback.invoke(null, new RequestError(RequestError.UNUSABLE_WEBHOOK, RequestType.REQUEST));
            return;
        }

        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, responseType));
    }

    function discardRegistration() as Void {
        Application.Storage.deleteValue(Webhook.REGISTRATION_KEY);
    }

    private function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        _gateway.post(path, body, handler);
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

    private function buildTemplateRenderRequest(target as Symbol) as Method {
        var body = {
            "type" => "render_template",
            "data" => {
                ResponseType.TEMPLATE_RENDER_ROOT_KEY => {
                    "template" => HaTemplate.resolve(target, VisibilityStore.getHiddenFloors(), VisibilityStore.getHiddenAreas())
                }
            }
        };

        return new WebhookRequest(self, body, ResponseType.TEMPLATE_RENDER).method(:attempt);
    }

    private function queueChange(request as Method, callback as Method) as Void {
        _changeQueue.add(new QueuedChange(request, callback));
        startNextRequest();
    }

    private function startNextRequest() as Void {
        if (_isRequestInFlight) {
            return;
        }

        if (_changeQueue.size() > 0) {
            var next = _changeQueue[0];
            _changeQueue = _changeQueue.slice(1, null) as Array<QueuedChange>;
            _isRequestInFlight = true;
            _isChangeInFlight = true;
            _pendingChangeCallback = next.callback;
            new RetryManager(next.request, method(:onChangeSettled), _scheduler, RequestType.REQUEST).attempt();
            return;
        }

        if (_pendingFetchTargets.size() > 0) {
            var target = _pendingFetchTargets[0];
            _pendingFetchTargets = _pendingFetchTargets.slice(1, null) as Array<Symbol>;
            _isRequestInFlight = true;
            _currentTarget = target;
            new RetryManager(buildTemplateRenderRequest(target), method(:onTargetSettled), _scheduler, RequestType.REQUEST).attempt();
        }
    }

    private function setRegistration(webhookId as String) as Void {
        Application.Storage.setValue(Webhook.REGISTRATION_KEY, webhookId);
    }
}
