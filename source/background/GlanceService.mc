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
            Settings.resolveBaseUrl() + "/api/webhook/" + webhookId,
            {
                "type" => "render_template",
                "data" => { ResponseType.TEMPLATE_RENDER_ROOT_KEY =>
                    { "template" => HaTemplate.resolve(FetchTarget.GLANCE,
                        VisibilityStore.getHiddenFloors(), VisibilityStore.getHiddenAreas(),
                        [] as Array<String>) } }
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => "Bearer " + Settings.getToken(),
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                }
            },
            method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code >= 200 && code < 300 && data instanceof Dictionary) {
            var payload = data.get(ResponseType.TEMPLATE_RENDER_ROOT_KEY);
            if (payload instanceof Dictionary && !ResponseType.isRenderError(payload)) {
                var summary = payload.get("lightSummary");
                GlanceSummary.setLightSummary(summary instanceof String ? summary : null);

                var climate = payload.get("climate");
                var averages = climate instanceof Dictionary ? climate : ({} as Dictionary);
                GlanceSummary.setTemperature(averages.get("temperature"));
                GlanceSummary.setHumidity(averages.get("humidity"));
            }
        }

        Background.exit(null);
    }
}
