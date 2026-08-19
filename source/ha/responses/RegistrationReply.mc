import Toybox.Lang;

// Monkey C has no closures, so something must carry the generation a
// registration was issued under until its reply lands.
class RegistrationReply {
    private var _client as HaClient;
    private var _generation as Number;

    function initialize(client as HaClient, generation as Number) {
        _client = client;
        _generation = generation;
    }

    function onReply(webhookId as String or Null, error as Number or Null) as Void {
        _client.onRegistrationReply(_generation, webhookId, error);
    }
}
