import Toybox.Lang;

// Bridges the split-payload client back to the combined-template caller
// still in use until Phase 5: ResponseHandler hands out a raw payload, and
// this converts it to the HomeState today's app and HomeSession still expect.
class LegacyHomeStateReply {
    private var _callback as Method;

    function initialize(callback as Method) {
        _callback = callback;
    }

    function onPayload(payload as Dictionary or String or Null, error as Number or Null) as Void {
        if (error != null) {
            _callback.invoke(null, error);
            return;
        }

        _callback.invoke(HomeState.fromTemplateData(payload), null);
    }
}
