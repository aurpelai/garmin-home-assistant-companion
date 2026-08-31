import Toybox.Lang;

typedef RequestGateway as interface {
    function post(path as String, body as Dictionary, handler as ResponseHandler) as Void;
    function cancelAll() as Void;
};
