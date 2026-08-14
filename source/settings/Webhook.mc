import Toybox.Application;
import Toybox.Lang;

// The registration the app derives from Settings, not a setting itself: the
// webhook id, one at a time. Registration now fires whenever the URL or token
// changes, so an id can never outlive the instance it was registered against.
module Webhook {

    function getId() as String or Null {
        return Application.Storage.getValue("webhookId") as String or Null;
    }

    function setId(webhookId as String) as Void {
        Application.Storage.setValue("webhookId", webhookId);
    }

    function clearId() as Void {
        Application.Storage.deleteValue("webhookId");
    }

}
