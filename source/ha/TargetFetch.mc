import Toybox.Lang;

// Binds a refresh target to HaClient.fetchTarget, so a per-target instance
// exposes the single-callback-argument shape RetryManager requires. Monkey C
// has no closures, so something must hold the target between the request and
// its retried reissue.
class TargetFetch {
    private var _client as HaClient;
    private var _target as Symbol;

    function initialize(client as HaClient, target as Symbol) {
        _client = client;
        _target = target;
    }

    function request(callback as Method) as Void {
        _client.fetchTarget(_target, callback);
    }
}
