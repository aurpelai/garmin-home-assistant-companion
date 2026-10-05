import Toybox.Lang;

class EpochHandler {
    private var _onSettled as Method;
    private var _epoch as Number;

    function initialize(onSettled as Method, epoch as Number) {
        _onSettled = onSettled;
        _epoch = epoch;
    }

    function onSettled(result as Object or Null, error as RequestError or Null) as Void {
        _onSettled.invoke(_epoch, result, error);
    }
}
