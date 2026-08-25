import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Keeps the glance's cached summaries fresh while the app is closed. A missing or
// dead webhook is left for the foreground to re-register next run, so the service
// just exits and leaves the last good summary in place rather than recovering.
(:background)
class GlanceService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var webhookId = Application.Storage.getValue(Webhook.REGISTRATION_KEY) as String or Null;
        if (webhookId == null || !Settings.isConfigured()) {
            Background.exit(null);
            return;
        }

        Communications.makeWebRequest(
            Settings.getBaseUrl() + "/api/webhook/" + webhookId,
            {
                "type" => "render_template",
                "data" => { ResponseType.TEMPLATE_RENDER_ROOT_KEY =>
                    { "template" => HaTemplate.resolve(FetchTarget.GLANCE) } }
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => "Bearer " + Settings.getToken(),
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code >= 200 && code < 300 && data instanceof Dictionary) {
            var rendered = data.get(ResponseType.TEMPLATE_RENDER_ROOT_KEY);
            var home = rendered instanceof String ? JsonParser.parse(rendered) : rendered;
            if (home instanceof Dictionary) {
                var lights = home.get("lights");
                GlanceSummary.setLights(lights instanceof String ? lights : null);

                var climate = home.get("climate");
                GlanceSummary.setClimate(GlanceSummary.climateLine(
                    climate instanceof Dictionary ? climate : ({} as Dictionary)));
            }
        }

        Background.exit(null);
    }
}
