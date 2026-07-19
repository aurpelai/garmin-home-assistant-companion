import Toybox.Graphics;
import Toybox.Lang;

// Shared text helpers for the simple centered-message screens (LoadingView,
// ErrorView). dc.drawText does not wrap, so we greedily word-wrap to the
// available width and draw the lines centered as a block.
module TextDraw {

    // Clear to black and draw `text` word-wrapped, centered in the screen.
    function centeredMessage(dc as Graphics.Dc, text as String) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var font = Graphics.FONT_MEDIUM;
        var maxWidth = (dc.getWidth() * 4) / 5;   // ~80%, clear of the bezel
        var lines = wrap(text, font, maxWidth, dc.method(:getTextWidthInPixels));

        var lineHeight = dc.getFontHeight(font);
        var startY = (dc.getHeight() / 2) - ((lineHeight * lines.size()) / 2);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(dc.getWidth() / 2, startY + (i * lineHeight),
                font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Greedy word wrap. `measure` is a function (text, font) -> pixel width
    // (dc.getTextWidthInPixels); injected so this logic is unit-testable without
    // a Dc. A single word wider than maxWidth is kept on its own line rather
    // than dropped.
    function wrap(text as String, font as Graphics.FontType, maxWidth as Number,
                  measure as Method(text as String, font as Graphics.FontType) as Number) as Array<String> {
        var words = splitOnSpaces(text);
        var lines = [] as Array<String>;
        var line = "";
        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            var candidate = line.equals("") ? word : line + " " + word;
            if (line.equals("") || measure.invoke(candidate, font) <= maxWidth) {
                line = candidate;
            } else {
                lines.add(line);
                line = word;
            }
        }
        if (!line.equals("")) {
            lines.add(line);
        }
        return lines;
    }

    // Split on single spaces (Monkey C String has no split()). Collapses runs
    // of spaces by skipping empty tokens.
    function splitOnSpaces(text as String) as Array<String> {
        var out = [] as Array<String>;
        var start = 0;
        var i = 0;
        var chars = text.toCharArray();
        while (i <= chars.size()) {
            if (i == chars.size() || chars[i] == ' ') {
                if (i > start) {
                    out.add(text.substring(start, i) as String);
                }
                start = i + 1;
            }
            i++;
        }
        return out;
    }
}
