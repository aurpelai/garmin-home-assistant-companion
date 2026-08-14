import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// The only object that talks to Home Assistant, and the only one that decides
// when. Knows no domain types: a fetch reply hands out a raw payload, and the
// caller (eventually the coordinator) parses it.
class HaClient {
    // The device can't introspect its real model/OS, so every install registers
    // under these same constants.
    private const DEVICE_ID = "companion_for_home_assistant";
    private const APP_ID = "companion_for_home_assistant";
    private const APP_NAME = "Companion For Home Assistant";
    private const APP_VERSION = "0.4.0";
    private const DEVICE_NAME = "Garmin Watch";
    private const MANUFACTURER = "Garmin";
    private const MODEL = "Connect IQ";
    private const OS_NAME = "Connect IQ";
    private const OS_VERSION = "1";

    // Fired in this order on every refresh; either arrival order is tolerated
    // downstream, so the order here is just the one chosen.
    private const REFRESH_TARGETS = [:structure, :lights, :sensors];

    // Piped through `| tojson`: the render_template webhook returns the rendered
    // value as a string, so without it the payload is a Python repr (single
    // quotes, True/False, enum units) that no JSON reader accepts. tojson makes
    // it well-formed JSON, which JsonParser then decodes on-device.
    //
    // Deliberately backslash-free: we filter entities with `.startswith(...)`
    // instead of a regex like select('match','^light\.'). A backslash in this
    // string would be sent unescaped by the Connect IQ JSON serializer, producing
    // an invalid JSON escape and a 400 "Invalid JSON specified" from HA.
    //
    // Every value reaching the closing `| tojson` is guarded at its own site.
    // An Undefined raises TypeError from inside tojson, before any later filter
    // runs, so `| tojson | default(...)` cannot catch it — one bad entity would
    // cost the whole payload rather than its own row.
    //
    // Every area is emitted, including empty ones: entity targets arrive
    // separately, so an area that looks empty here may be populated later.
    private const STRUCTURE_TEMPLATE =
        "{% set ns = namespace(areasOut={}, floorsOut={}) %}" +
        "{% for a in areas() %}" +
        "{% set ns.areasOut = dict(ns.areasOut, **{a: dict(name=area_name(a) | default(none))}) %}" +
        "{% endfor %}" +
        "{% for f in floors() %}" +
        "{% set ns.floorsOut = dict(ns.floorsOut, **{f: dict(" +
            "name=floor_name(f) | default(none), order=loop.index0, " +
            "areas=floor_areas(f) | default([]) | list)}) %}" +
        "{% endfor %}" +
        "{{ dict(zone=state_attr('zone.home', 'friendly_name'), " +
            "areas=ns.areasOut, floors=ns.floorsOut) | tojson }}";

    // Each light carries its own area id and, for a group, its member ids —
    // the area's own light list is gone, so grouping moves to the parser.
    private const LIGHTS_TEMPLATE =
        "{% set ns = namespace(out={}) %}" +
        "{% for a in areas() %}" +
        "{% for e in area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('light.') and states[e] is not none %}" +
        "{% set members = expand(e) | rejectattr('entity_id', 'is_hidden_entity') " +
            "| map(attribute='entity_id') | list %}" +
        "{% if state_attr(e, 'entity_id') is none or members | count > 0 %}" +
        "{% set light = dict(state=is_state(e, 'on'), name=states[e].name, area_id=a, " +
            "available=not is_state(e, 'unavailable')) %}" +
        "{% if state_attr(e, 'entity_id') is not none %}" +
        "{% set light = dict(light, memberIds=members) %}" +
        "{% endif %}" +
        "{% set ns.out = dict(ns.out, **{e: light}) %}" +
        "{% endif %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(lights=ns.out) | tojson }}";

    // `states(e, true, true)` keeps HA's own display precision and unit as a
    // string, so the watch never reparses or rounds and can't disagree with
    // the user's dashboard. Needs HA 2023.3.
    //
    // `float(none)`, never `float(0)`: a non-numeric state defaulted to 0 is
    // indistinguishable from a sensor genuinely reading zero, so an area mean
    // would silently absorb it — one unavailable sensor plus a real 21.5 °C
    // shows 10.8 °C. null makes the absence visible to the parser instead.
    private const SENSORS_TEMPLATE =
        "{% set ns = namespace(out={}) %}" +
        "{% for a in areas() %}" +
        "{% for e in area_entities(a) | reject('is_hidden_entity') | list %}" +
        "{% if e.startswith('sensor.') and states[e] is not none " +
            "and state_attr(e, 'device_class') in ['temperature', 'humidity', 'illuminance'] %}" +
        "{% set ns.out = dict(ns.out, **{e: dict(" +
            "state=states(e) | float(none), display_state=states(e, true, true), " +
            "unit=state_attr(e, 'unit_of_measurement'), " +
            "device_class=state_attr(e, 'device_class'), area_id=a, name=entity_name(e), " +
            "available=not is_state(e, 'unavailable') and not is_state(e, 'unknown'))}) %}" +
        "{% endif %}" +
        "{% endfor %}" +
        "{% endfor %}" +
        "{{ dict(sensors=ns.out) | tojson }}";

    // One outstanding request of any kind: exceeding it yields a queue-full
    // transport error, so a refresh and a service call compete for this one
    // slot.
    private var _requestInFlight as Boolean;

    // Whether the request currently in the slot is a change rather than a
    // fetch target — the narrower question a refresh trigger needs answered,
    // instead of a general in-flight flag every site would reuse loosely.
    private var _changeInFlight as Boolean;

    private var _changeQueue as Array<QueuedChange>;
    private var _pendingChangeCallback as Method or Null;

    // Targets still to fetch in the refresh currently running; empty means no
    // refresh is in progress. A trigger arriving while this is non-empty is
    // dropped rather than coalesced target-by-target.
    private var _pendingFetchTargets as Array<Symbol>;

    private var _currentTarget as Symbol or Null;
    private var _onRefreshTarget as Method or Null;

    private var _refreshHadFailure as Boolean;

    private var _lastRefreshCompletedAt as Number or Null;
    private var _lastError as Number or Null;

    function initialize() {
        _requestInFlight = false;
        _changeInFlight = false;
        _changeQueue = [];
        _pendingChangeCallback = null;
        _pendingFetchTargets = [];
        _currentTarget = null;
        _onRefreshTarget = null;
        _refreshHadFailure = false;
        _lastRefreshCompletedAt = null;
        _lastError = null;
    }

    function msSinceLastRefresh() as Number or Null {
        return _lastRefreshCompletedAt == null ? null : System.getTimer() - (_lastRefreshCompletedAt as Number);
    }

    function lastError() as Number or Null {
        return _lastError;
    }

    // A trigger arriving while a refresh is already outstanding is dropped:
    // once a target has landed it is no longer outstanding, so a fresh
    // request for it would refetch data already in hand.
    //
    // A trigger arriving while a change is outstanding — queued or currently
    // in the slot — is dropped too: converging against server truth is
    // pointless when more changes are about to be posted, and the caller
    // (the coordinator) is expected to ask again once its own reply lands.
    function refresh(onTarget as Method) as Void {
        if (_pendingFetchTargets.size() > 0 || _changeQueue.size() > 0 || _changeInFlight) {
            return;
        }

        _pendingFetchTargets = REFRESH_TARGETS.slice(0, null) as Array<Symbol>;
        _refreshHadFailure = false;
        _onRefreshTarget = onTarget;
        drainSlot();
    }

    function queueLightToggle(entityId as String, callback as Method) as Void {
        queueChange(new ServiceCall(self, "toggle", "entity_id", entityId).method(:call), callback);
    }

    function queueFloorLights(floorId as String, service as String, callback as Method) as Void {
        queueChange(new ServiceCall(self, service, "floor_id", floorId).method(:call), callback);
    }

    // Drops the queue, the last error and the slot together. The rebuild
    // sequence is the one caller: a settings change discards everything rather
    // than letting a stale request's reply land against fresh state.
    function cancelAll() as Void {
        Communications.cancelAllRequests();
        _changeQueue = [];
        _pendingFetchTargets = [];
        _lastError = null;
        _requestInFlight = false;
        _changeInFlight = false;
        _pendingChangeCallback = null;
        _currentTarget = null;
        _onRefreshTarget = null;
    }

    private function queueChange(request as Method, callback as Method) as Void {
        _changeQueue.add(new QueuedChange(request, callback));
        drainSlot();
    }

    // Changes go out before fetches, and a fetch never starts while any
    // change is queued or in flight — this is where the next change or
    // target is chosen, once the slot is free.
    private function drainSlot() as Void {
        if (_requestInFlight) {
            return;
        }

        if (_changeQueue.size() > 0) {
            var next = _changeQueue[0];
            _changeQueue = _changeQueue.slice(1, null) as Array<QueuedChange>;
            _requestInFlight = true;
            _changeInFlight = true;
            _pendingChangeCallback = next.callback;
            new RetryManager(self, next.request, method(:onChangeSettled)).attempt();
            return;
        }

        if (_pendingFetchTargets.size() > 0) {
            var target = _pendingFetchTargets[0];
            _pendingFetchTargets = _pendingFetchTargets.slice(1, null) as Array<Symbol>;
            _requestInFlight = true;
            _currentTarget = target;
            new RetryManager(self, new TargetFetch(self, target).method(:request), method(:onTargetSettled))
                .attempt();
        }
    }

    function onChangeSettled(result as Object or Null, error as Number or Null) as Void {
        _requestInFlight = false;
        _changeInFlight = false;

        // A cancelled request's reply can still arrive: cancelAll already
        // nulled this, and there is nothing left to notify or converge.
        if (_pendingChangeCallback == null) {
            return;
        }

        var callback = _pendingChangeCallback as Method;
        _pendingChangeCallback = null;

        // A transport failure drains the remaining queued changes only once
        // RetryManager's own threshold is exhausted, never on the first
        // failure: one failed reply is a hypothesis, and exhausting the
        // threshold is what turns it into a verdict that the link is down.
        if (error != null) {
            _lastError = error;
            _changeQueue = [];
        } else {
            _lastError = null;
        }

        callback.invoke(result, error);

        // A reply does not start a refresh while further changes are
        // outstanding: converging against server truth is pointless when
        // more changes are about to be posted.
        drainSlot();
    }

    function onTargetSettled(result as Object or Null, error as Number or Null) as Void {
        _requestInFlight = false;

        // A cancelled request's reply can still arrive: cancelAll already
        // nulled these, and pushing a cancelled target's payload into
        // whatever state now exists would be wrong.
        if (_currentTarget == null || _onRefreshTarget == null) {
            return;
        }

        var target = _currentTarget as Symbol;
        var onTarget = _onRefreshTarget as Method;

        if (error != null) {
            _refreshHadFailure = true;
            _lastError = error;
        } else {
            _lastError = null;
        }

        onTarget.invoke(target, result, error);

        if (_pendingFetchTargets.size() == 0 && !_refreshHadFailure) {
            _lastRefreshCompletedAt = System.getTimer();
        }

        drainSlot();
    }

    // Package-visible for TargetFetch, which binds one target to this so a
    // per-target instance exposes the single-callback-argument shape
    // RetryManager requires.
    function fetchTarget(target as Symbol, callback as Method) as Void {
        postFetchTemplate(templateFor(target), callback);
    }

    function register(callback as Method) as Void {
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
        post("/api/mobile_app/registrations", body,
             new ResponseHandler(new RegisterCacheHandler(callback).method(:onRegistered), :registration));
    }

    private function postFetchTemplate(template as String, callback as Method) as Void {
        var webhookId = Webhook.getId();

        if (webhookId == null) {
            callback.invoke(null, 404);
            return;
        }

        var body = {
            "type" => "render_template",
            "data" => {
                "home" => {
                    "template" => template
                }
            }
        };
        post("/api/webhook/" + webhookId, body, new ResponseHandler(callback, :fetch));
    }

    private function templateFor(target as Symbol) as String {
        if (target == :structure) {
            return STRUCTURE_TEMPLATE;
        }
        if (target == :lights) {
            return LIGHTS_TEMPLATE;
        }
        return SENSORS_TEMPLATE;
    }

    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + Settings.getToken(),
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            Settings.getBaseUrl() + path,
            body as Dictionary<Object, Object>,
            options,
            handler.method(:onResponse)
        );
    }
}
