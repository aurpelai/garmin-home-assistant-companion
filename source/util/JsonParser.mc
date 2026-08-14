import Toybox.Lang;
import Toybox.StringUtil;

// Single-pass JSON string -> native Dictionary/Array/primitive decoder.
//
// HA's render_template webhook returns the rendered template as a STRING inside
// the JSON envelope, so Connect IQ decodes the envelope but hands the payload
// back as an unparsed String (double-encoded). This decodes that inner string.
//
// One pass over a char-code array, no backtracking, minimal allocation: the
// payload grows with home size and an on-device parse that runs too long trips
// the "code took too long to run" watchdog. Malformed input yields null rather
// than throwing.
class JsonParser {
    private var _str as String;
    // Char units, not bytes: _pos indexes both this and _str.substring, which is
    // character-indexed — a byte array (toUtf8Array) would desync the two on any
    // multi-byte character and corrupt the extracted substring.
    private var _chars as Array<Char>;
    private var _pos as Number;
    private var _len as Number;

    function initialize(str as String) {
        _str = str;
        _chars = str.toCharArray();
        _pos = 0;
        _len = _chars.size();
    }

    static function parse(str as String) as Object or Null {
        return new JsonParser(str).parseDocument();
    }

    function parseDocument() as Object or Null {
        skipWhitespace();
        var value = parseValue();
        skipWhitespace();
        return _pos == _len ? value : null;
    }

    private function parseValue() as Object or Null {
        skipWhitespace();
        if (_pos >= _len) {
            return null;
        }
        var c = _chars[_pos];
        if (c == 0x7B) { // {
            return parseObject();
        }
        if (c == 0x5B) { // [
            return parseArray();
        }
        if (c == 0x22) { // "
            return parseString();
        }
        if (c == 0x74) { // t
            return parseLiteral("true", true);
        }
        if (c == 0x66) { // f
            return parseLiteral("false", false);
        }
        if (c == 0x6E) { // n
            return parseLiteral("null", null);
        }
        if (c == 0x2D || (c >= 0x30 && c <= 0x39)) { // - or digit
            return parseNumber();
        }
        return null;
    }

    // Lets callers reject a missing value like `{"a": }`, which parseValue alone
    // can't: its null return is ambiguous with a legitimate `null` literal.
    private function valueStartsHere() as Boolean {
        skipWhitespace();
        if (_pos >= _len) {
            return false;
        }
        var c = _chars[_pos];
        return c == 0x7B || c == 0x5B || c == 0x22 || c == 0x74 || c == 0x66
            || c == 0x6E || c == 0x2D || (c >= 0x30 && c <= 0x39);
    }

    private function parseObject() as Dictionary or Null {
        var out = {} as Dictionary;
        _pos++;
        if (consumeClose(0x7D)) { // }
            return out;
        }

        var more = true;
        while (more) {
            if (!parseMember(out)) {
                return null;
            }
            more = consumeComma();
        }

        return consumeClose(0x7D) ? out : null; // }
    }

    // Reads one "key": value pair into out; false on any malformed part.
    private function parseMember(out as Dictionary) as Boolean {
        skipWhitespace();
        if (_pos >= _len || _chars[_pos] != 0x22) { // "
            return false;
        }
        var key = parseString();
        if (key == null) {
            return false;
        }
        skipWhitespace();
        if (_pos >= _len || _chars[_pos] != 0x3A) { // :
            return false;
        }
        _pos++;
        if (!valueStartsHere()) {
            return false;
        }
        out.put(key, parseValue());
        return true;
    }

    private function parseArray() as Array or Null {
        var out = [] as Array;
        _pos++;
        if (consumeClose(0x5D)) { // ]
            return out;
        }

        var more = true;
        while (more) {
            if (!valueStartsHere()) {
                return null;
            }
            out.add(parseValue());
            more = consumeComma();
        }

        return consumeClose(0x5D) ? out : null; // ]
    }

    // Consumes a closing bracket at the current position (past whitespace),
    // reporting whether the container ended here.
    private function consumeClose(bracket as Number) as Boolean {
        skipWhitespace();
        if (_pos < _len && _chars[_pos] == bracket) {
            _pos++;
            return true;
        }
        return false;
    }

    // Consumes a separating comma, reporting whether another element follows.
    private function consumeComma() as Boolean {
        skipWhitespace();
        if (_pos < _len && _chars[_pos] == 0x2C) { // ,
            _pos++;
            return true;
        }
        return false;
    }

    // Escape-free strings (the common case) take one substring; only a string
    // that actually contains a backslash walks segment-by-segment.
    private function parseString() as String or Null {
        _pos++;
        var start = _pos;
        while (_pos < _len) {
            var c = _chars[_pos];
            if (c == 0x22) { // "
                var result = _str.substring(start, _pos);
                _pos++;
                return result;
            }
            if (c == 0x5C) { // \
                return parseEscapedString(start);
            }
            _pos++;
        }
        return null;
    }

    private function parseEscapedString(start as Number) as String or Null {
        var result = _str.substring(start, _pos) as String;
        while (_pos < _len) {
            var c = _chars[_pos];
            if (c == 0x22) { // "
                _pos++;
                return result;
            }
            if (c != 0x5C) { // \
                var runStart = _pos;
                while (_pos < _len && _chars[_pos] != 0x22 && _chars[_pos] != 0x5C) {
                    _pos++;
                }
                result += _str.substring(runStart, _pos);
                continue;
            }
            _pos++;
            if (_pos >= _len) {
                return null;
            }
            var esc = _chars[_pos];
            if (esc == 0x75) { // u
                var decoded = parseUnicodeEscape();
                if (decoded == null) {
                    return null;
                }
                result += decoded;
            } else {
                result += unescapeSimple(esc.toNumber());
                _pos++;
            }
        }
        return null;
    }

    private function unescapeSimple(esc as Number) as String {
        if (esc == 0x6E) { // n
            return "\n";
        }
        if (esc == 0x74) { // t
            return "\t";
        }
        if (esc == 0x72) { // r
            return "\r";
        }
        if (esc == 0x62) { // b
            return "\b";
        }
        if (esc == 0x66) { // f
            return "\f";
        }
        // \" \\ \/ and any other single-char escape: the char stands for itself.
        return _str.substring(_pos, _pos + 1) as String;
    }

    private function parseUnicodeEscape() as String or Null {
        if (_pos + 4 >= _len) {
            return null;
        }
        var code = 0;
        for (var i = 1; i <= 4; i++) {
            var digit = hexValue(_chars[_pos + i].toNumber());
            if (digit < 0) {
                return null;
            }
            code = (code << 4) | digit;
        }
        _pos += 5;
        return codePointToString(code);
    }

    private function hexValue(c as Number) as Number {
        if (c >= 0x30 && c <= 0x39) { // 0-9
            return c - 0x30;
        }
        if (c >= 0x41 && c <= 0x46) { // A-F
            return c - 0x37;
        }
        if (c >= 0x61 && c <= 0x66) { // a-f
            return c - 0x57;
        }
        return -1;
    }

    private function codePointToString(code as Number) as String {
        var bytes = [] as Array<Number>;
        if (code < 0x80) {
            bytes.add(code);
        } else if (code < 0x800) {
            bytes.add(0xC0 | ((code >> 6) & 0x1F));
            bytes.add(0x80 | (code & 0x3F));
        } else {
            bytes.add(0xE0 | ((code >> 12) & 0x0F));
            bytes.add(0x80 | ((code >> 6) & 0x3F));
            bytes.add(0x80 | (code & 0x3F));
        }
        return StringUtil.utf8ArrayToString(bytes);
    }

    // Each structural char is allowed at most once and only where JSON permits:
    // a dot before any exponent, one exponent marker, and a sign only right after
    // it. A char that breaks the grammar ends the number, leaving the caller to
    // reject the trailing garbage rather than accepting e.g. `1.2.3`.
    private function parseNumber() as Object or Null {
        var start = _pos;
        var hasDot = false;
        var hasExp = false;
        var prevWasExp = false;
        if (_pos < _len && _chars[_pos] == 0x2D) { // -
            _pos++;
        }
        while (_pos < _len) {
            var c = _chars[_pos];
            var isExp = false;
            if (c >= 0x30 && c <= 0x39) {
                // digit always allowed
            } else if (c == 0x2E && !hasDot && !hasExp) { // .
                hasDot = true;
            } else if ((c == 0x65 || c == 0x45) && !hasExp) { // e E
                hasExp = true;
                isExp = true;
            } else if ((c == 0x2B || c == 0x2D) && prevWasExp) { // + -
                // sign only immediately after the exponent marker
            } else {
                break;
            }
            prevWasExp = isExp;
            _pos++;
        }
        if (_pos == start) {
            return null;
        }
        var text = _str.substring(start, _pos);
        if (text == null) {
            return null;
        }
        if (!hasDot && !hasExp) {
            var asNumber = text.toNumber();
            if (asNumber != null) {
                return asNumber;
            }
        }
        return text.toFloat();
    }

    private function parseLiteral(word as String, value as Object or Null) as Object or Null {
        var chars = word.toUtf8Array();
        if (_pos + chars.size() > _len) {
            return null;
        }
        for (var i = 0; i < chars.size(); i++) {
            if (_chars[_pos + i] != chars[i]) {
                return null;
            }
        }
        _pos += chars.size();
        return value;
    }

    private function skipWhitespace() as Void {
        while (_pos < _len) {
            var c = _chars[_pos];
            if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
                _pos++;
            } else {
                return;
            }
        }
    }
}
