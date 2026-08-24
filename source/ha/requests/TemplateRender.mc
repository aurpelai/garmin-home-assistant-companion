import Toybox.Lang;

class TemplateRender {
    private var _client as HaClient;
    private var _template as String;

    function initialize(client as HaClient, template as String) {
        _client = client;
        _template = template;
    }

    function attempt(callback as Method) as Void {
        _client.postTemplate(_template, callback);
    }
}
