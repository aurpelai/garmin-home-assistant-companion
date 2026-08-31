import Toybox.Lang;

typedef RequestSender as interface {
    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void;
    function cancelAll() as Void;
};
