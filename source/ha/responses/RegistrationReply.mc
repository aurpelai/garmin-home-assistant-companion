import Toybox.Lang;

// Monkey C has no closures, so something must carry the epoch a registration
// was issued under until its reply lands.
class RegistrationReply {
    private var _client as HaClient;
    private var _epoch as Number;

    function initialize(client as HaClient, epoch as Number) {
        _client = client;
        _epoch = epoch;
    }

    function onReply(webhookId as String or Null, error as Number or Null) as Void {
        _client.onRegistrationReply(_epoch, webhookId, error);
    }
}
