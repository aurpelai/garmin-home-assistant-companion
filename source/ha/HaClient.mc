import Toybox.Application;
import Toybox.Communications;
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
    private const REGISTRATION_KEY = "webhookId";

    // UNVERIFIED: the device can't introspect its real model/OS, so every
    // install registers under these same constants.
    private const DEVICE_ID = "companion_for_home_assistant";
    private const APP_ID = "companion_for_home_assistant";
    private const APP_NAME = "Companion For Home Assistant";
    private const APP_VERSION = "0.8.0";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    private const REFRESH_TARGETS = [FetchTarget.STRUCTURE, FetchTarget.LIGHTS, FetchTarget.SENSORS];

    private var _requestInFlight as Boolean;
    private var _changeInFlight as Boolean;
    private var _changeQueue as Array<QueuedChange>;
    private var _pendingChangeCallback as Method or Null;
    private var _registrationCallback as Method or Null;
    private var _registrationEpoch as Number;
    private var _pendingFetchTargets as Array<Symbol>;
    private var _currentTarget as Symbol or Null;
    private var _onRefreshTarget as Method or Null;
    private var _refreshError as RequestError or Null;
    private var _lastRefreshCompletedAt as Number or Null;

    function initialize() {
        _requestInFlight = false;
        _changeInFlight = false;
        _changeQueue = [];
        _pendingChangeCallback = null;
        _registrationCallback = null;
        _registrationEpoch = 0;
        _pendingFetchTargets = [];
        _currentTarget = null;
        _onRefreshTarget = null;
        _refreshError = null;
        _lastRefreshCompletedAt = null;
    }

    function isRefreshing() as Boolean {
        return _pendingFetchTargets.size() > 0;
    }

    function hasOutstandingChanges() as Boolean {
        return _changeQueue.size() > 0 || _changeInFlight;
    }

    function msSinceLastRefresh() as Number or Null {
        return _lastRefreshCompletedAt == null ? null : System.getTimer() - (_lastRefreshCompletedAt as Number);
    }

    function refreshResult() as RefreshResult {
        return new RefreshResult(_refreshError, _lastRefreshCompletedAt != null);
    }

    function refresh(onTarget as Method) as Void {
        if (isRefreshing() || hasOutstandingChanges()) {
            return;
        }

        _pendingFetchTargets = REFRESH_TARGETS.slice(0, null) as Array<Symbol>;
        _refreshError = null;
        _onRefreshTarget = onTarget;
        startNextRequest();
    }

    function queueLightToggle(entityId as String, callback as Method) as Void {
        queueChange(new ServiceCall(self, "toggle", "entity_id", entityId).method(:attempt), callback);
    }

    function queueFloorLights(floorId as String, service as String, callback as Method) as Void {
        queueChange(new ServiceCall(self, service, "floor_id", floorId).method(:attempt), callback);
    }

    // UNVERIFIED: Connect IQ still delivers a cancelled request's reply, so the
    // callbacks are nulled to drop it.
    function cancelAll() as Void {
        Communications.cancelAllRequests();
        _changeQueue = [];
        _pendingFetchTargets = [];
        _requestInFlight = false;
        _changeInFlight = false;
        _pendingChangeCallback = null;
        _registrationCallback = null;
        _registrationEpoch++;
        _currentTarget = null;
        _onRefreshTarget = null;
    }

    private function queueChange(request as Method, callback as Method) as Void {
        _changeQueue.add(new QueuedChange(request, callback));
        startNextRequest();
    }

    private function startNextRequest() as Void {
        if (_requestInFlight) {
            return;
        }

        if (_changeQueue.size() > 0) {
            var next = _changeQueue[0];
            _changeQueue = _changeQueue.slice(1, null) as Array<QueuedChange>;
            _requestInFlight = true;
            _changeInFlight = true;
            _pendingChangeCallback = next.callback;
            new RetryManager(next.request, method(:onChangeSettled), RequestType.REQUEST).attempt();
            return;
        }

        if (_pendingFetchTargets.size() > 0) {
            var target = _pendingFetchTargets[0];
            _pendingFetchTargets = _pendingFetchTargets.slice(1, null) as Array<Symbol>;
            _requestInFlight = true;
            _currentTarget = target;
            new RetryManager(new TemplateRender(self, HaTemplate.resolve(target)).method(:attempt),
                             method(:onTargetSettled), RequestType.REQUEST).attempt();
        }
    }

    function onChangeSettled(result as Object or Null, spentError as RequestError or Null) as Void {
        _requestInFlight = false;
        _changeInFlight = false;

        if (_pendingChangeCallback == null) {
            return;
        }

        var callback = _pendingChangeCallback as Method;
        _pendingChangeCallback = null;

        if (spentError != null) {
            _changeQueue = [];
        }

        callback.invoke(result, spentError);
        startNextRequest();
    }

    function onTargetSettled(result as Object or Null, spentError as RequestError or Null) as Void {
        _requestInFlight = false;

        if (_currentTarget == null || _onRefreshTarget == null) {
            return;
        }

        var target = _currentTarget as Symbol;
        var onTarget = _onRefreshTarget as Method;

        if (_refreshError == null) {
            _refreshError = spentError;
        }

        var isLastTarget = !isRefreshing();

        if (isLastTarget && _refreshError == null) {
            _lastRefreshCompletedAt = System.getTimer();
        }

        onTarget.invoke(target, result, isLastTarget);
        startNextRequest();
    }

    function registerWithHomeAssistant(callback as Method) as Void {
        new RetryManager(method(:attemptRegistration), callback, RequestType.REGISTRATION).attempt();
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
             new ResponseHandler(new RegistrationReply(self, _registrationEpoch).method(:onReply),
                                 ResponseType.REGISTRATION),
             Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON);
    }

    function attemptRequest(body as Dictionary, callback as Method, responseType as Symbol,
                            responseContentType as Communications.HttpResponseContentType) as Void {
        var webhookId = Application.Storage.getValue(REGISTRATION_KEY) as String or Null;

        if (webhookId == null) {
            callback.invoke(null, RequestError.UNUSABLE_WEBHOOK);
            return;
        }

        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, responseType),
             responseContentType);
    }

    function onRegistrationReply(epoch as Number, webhookId as String or Null,
                                 error as Number or Null) as Void {
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

    function discardRegistration() as Void {
        Application.Storage.deleteValue(REGISTRATION_KEY);
    }

    private function setRegistration(webhookId as String) as Void {
        Application.Storage.setValue(REGISTRATION_KEY, webhookId);
    }

    function postTemplate(template as String, callback as Method) as Void {
        var body = {
            "type" => "render_template",
            "data" => {
                ResponseType.TEMPLATE_RENDER_ROOT_KEY => {
                    "template" => template
                }
            }
        };
        // The webhook answers a JSON object of the named renders it was sent, so
        // the response is application/json, not the rendered string alone (see #73).
        new WebhookRequest(self, body, ResponseType.TEMPLATE_RENDER,
                           Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON).attempt(callback);
    }

    function post(path as String, body as Dictionary, handler as ResponseHandler,
                  responseContentType as Communications.HttpResponseContentType) as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + Settings.getToken(),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => responseContentType
        };

        Communications.makeWebRequest(
            Settings.getBaseUrl() + path,
            body as Dictionary<Object, Object>,
            options,
            handler.method(:onResponse)
        );
    }
}
