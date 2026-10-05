import Toybox.Lang;

typedef RequestGateway as interface {
    function post(path as String, body as Dictionary, onResponse as Method) as Void;
    function cancelAll() as Void;
};
