import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Tests for the pure line-splitting logic. A fake measure function models a
// monospace font: 10 px per character.
(:test)
module CenteredMessageTest {

    function fakeMeasure(text as String, font as Graphics.FontType) as Number {
        return text.length() * 10;
    }
}

(:test)
function shortTextStaysOnOneLine(logger as Test.Logger) as Boolean {
    var lines = CenteredMessage.splitToLines("hi there", Graphics.FONT_MEDIUM, 200,
        new Lang.Method(CenteredMessageTest, :fakeMeasure));
    Test.assertEqual(lines.size(), 1);
    Test.assertEqual(lines[0], "hi there");
    return true;
}

(:test)
function textBreaksOnWidth(logger as Test.Logger) as Boolean {
    // maxWidth 100 px = 10 chars. "aaaa bbbb cccc" -> "aaaa bbbb" (9) then "cccc".
    var lines = CenteredMessage.splitToLines("aaaa bbbb cccc", Graphics.FONT_MEDIUM, 100,
        new Lang.Method(CenteredMessageTest, :fakeMeasure));
    Test.assertEqual(lines.size(), 2);
    Test.assertEqual(lines[0], "aaaa bbbb");
    Test.assertEqual(lines[1], "cccc");
    return true;
}

(:test)
function explicitNewlineForcesBreak(logger as Test.Logger) as Boolean {
    // "\n" breaks even when the text would otherwise fit on one line.
    var lines = CenteredMessage.splitToLines("hi\nthere", Graphics.FONT_MEDIUM, 200,
        new Lang.Method(CenteredMessageTest, :fakeMeasure));
    Test.assertEqual(lines.size(), 2);
    Test.assertEqual(lines[0], "hi");
    Test.assertEqual(lines[1], "there");
    return true;
}

(:test)
function blankLineBetweenParagraphs(logger as Test.Logger) as Boolean {
    // "\n\n" leaves one empty line between the two paragraphs.
    var lines = CenteredMessage.splitToLines("first\n\nsecond", Graphics.FONT_MEDIUM, 200,
        new Lang.Method(CenteredMessageTest, :fakeMeasure));
    Test.assertEqual(lines.size(), 3);
    Test.assertEqual(lines[0], "first");
    Test.assertEqual(lines[1], "");
    Test.assertEqual(lines[2], "second");
    return true;
}

(:test)
function overlongWordKeepsOwnLine(logger as Test.Logger) as Boolean {
    // "supercalifragilistic" (20 chars = 200px) exceeds maxWidth 100 but must
    // not be dropped — it gets its own line.
    var lines = CenteredMessage.splitToLines("hi supercalifragilistic ok", Graphics.FONT_MEDIUM, 100,
        new Lang.Method(CenteredMessageTest, :fakeMeasure));
    Test.assertEqual(lines.size(), 3);
    Test.assertEqual(lines[0], "hi");
    Test.assertEqual(lines[1], "supercalifragilistic");
    Test.assertEqual(lines[2], "ok");
    return true;
}
