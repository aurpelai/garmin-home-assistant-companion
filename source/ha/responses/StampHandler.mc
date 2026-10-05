import Toybox.Lang;

class StampHandler {
    private var _onSettled as Method;
    private var _stamp as Number;

    function initialize(onSettled as Method, stamp as Number) {
        _onSettled = onSettled;
        _stamp = stamp;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _onSettled.invoke(_stamp, result, error);
    }
}
