import Toybox.Lang;
import Toybox.Test;

(:test)
class ResultCapture {
    public var result as Object?;
    public var error as Object?;

    function onResult(result as Object?, error as Object?) as Void {
        self.result = result;
        self.error = error;
    }
}

(:test)
function onResponseNormalizesNon200ToError(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER);

    handler.onResponse(401, null);

    Test.assert(capture.result == null);
    Test.assertEqual((capture.error as RequestError).reason as Number, 401);
    return true;
}

(:test)
function aRenderedDictionaryIsThePayload(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, {
        ResponseType.TEMPLATE_RENDER_ROOT_KEY => { "lights" => { "light.a" => { "state" => true } } }
    });

    Test.assertEqual(((capture.result as Dictionary).get("lights") as Dictionary).size(), 1);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function anErrorObjectInPlaceOfTheRenderIsAFailedRender(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, {
        ResponseType.TEMPLATE_RENDER_ROOT_KEY => { "error" => "UndefinedError: 'x' is undefined" }
    });

    Test.assert(capture.result == null);
    Test.assertEqual((capture.error as RequestError).reason as Symbol, RequestError.TEMPLATE_ERROR);
    return true;
}

(:test)
function aRenderThatIsNotADictionaryIsUnreadable(logger as Test.Logger) as Boolean {
    var missing = new ResultCapture();
    new ResponseHandler(missing.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, {});

    Test.assert(missing.result == null);
    Test.assertEqual((missing.error as RequestError).reason as Symbol, RequestError.UNREADABLE_BODY);

    var string = new ResultCapture();
    new ResponseHandler(string.method(:onResult), ResponseType.TEMPLATE_RENDER)
        .onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => "{'changed': datetime(...)}" });

    Test.assert(string.result == null);
    Test.assertEqual((string.error as RequestError).reason as Symbol, RequestError.UNREADABLE_BODY);

    var list = new ResultCapture();
    new ResponseHandler(list.method(:onResult), ResponseType.TEMPLATE_RENDER)
        .onResponse(200, { ResponseType.TEMPLATE_RENDER_ROOT_KEY => [] });

    Test.assert(list.result == null);
    Test.assertEqual((list.error as RequestError).reason as Symbol, RequestError.UNREADABLE_BODY);
    return true;
}

(:test)
function aDeadWebhooksEmptyBodyIsUnusableRatherThanUnreadable(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    new ResponseHandler(capture.method(:onResult), ResponseType.TEMPLATE_RENDER).onResponse(200, null);

    Test.assert(capture.result == null);
    Test.assertEqual((capture.error as RequestError).reason as Symbol, RequestError.UNUSABLE_WEBHOOK);
    return true;
}

(:test)
function onResponseNormalizesServiceCallSuccessToTrue(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.SERVICE_CALL);

    handler.onResponse(200, null);

    Test.assertEqual(capture.result as Boolean, true);
    Test.assert(capture.error == null);
    return true;
}

(:test)
function onResponseNormalizesRegistrationSuccessToWebhookId(logger as Test.Logger) as Boolean {
    var capture = new ResultCapture();
    var handler = new ResponseHandler(capture.method(:onResult), ResponseType.REGISTRATION);

    handler.onResponse(201, { "webhook_id" => "abc123" });

    Test.assertEqual(capture.result as String, "abc123");
    Test.assert(capture.error == null);
    return true;
}
