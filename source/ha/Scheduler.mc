import Toybox.Lang;

// Runs one action later, off the current call stack. A single instance is shared
// across the retry managers so the whole client holds one timer — well clear of
// the platform's small timer budget — which is safe because only one retry is
// ever pending at a time under the one-outstanding-request serialisation.
typedef Scheduler as interface {
    function schedule(action as Method() as Void, delayMs as Number) as Void;
    function cancel() as Void;
};
