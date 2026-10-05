import Toybox.Lang;
import Toybox.Test;

(:test)
function aDiagnosticCodeWithNoRequestIsTheReasonAlone(logger as Test.Logger) as Boolean {
    Test.assertEqual(new RequestError(-1, null).toDiagnosticCode(), "-1");
    Test.assertEqual(new RequestError(RequestError.UNREADABLE_BODY, null).toDiagnosticCode(), "unreadableBody");
    return true;
}

(:test)
function aDiagnosticCodeNamesTheReasonThenTheRequest(logger as Test.Logger) as Boolean {
    Test.assertEqual(new RequestError(RequestError.TEMPLATE_ERROR, FetchTarget.LIGHTS).toDiagnosticCode(),
        "templateError (lights)");
    Test.assertEqual(new RequestError(RequestError.UNUSABLE_WEBHOOK, FetchTarget.STRUCTURE).toDiagnosticCode(),
        "unusableWebhook (structure)");
    Test.assertEqual(new RequestError(HttpStatus.BAD_REQUEST, FetchTarget.SENSORS).toDiagnosticCode(),
        "400 (sensors)");
    Test.assertEqual(new RequestError(HttpStatus.BAD_REQUEST, FetchTarget.FANS).toDiagnosticCode(),
        "400 (fans)");
    Test.assertEqual(new RequestError(HttpStatus.BAD_REQUEST, RequestType.REGISTRATION).toDiagnosticCode(),
        "400 (registration)");
    return true;
}
