import Toybox.Lang;
import Toybox.StringUtil;

// Single-pass JSON string -> native Dictionary/Array/primitive decoder.
//
// HA's render_template webhook returns the rendered template as a STRING inside
// the JSON envelope, so Connect IQ decodes the envelope but hands the payload
// back as an unparsed String (double-encoded, see #68). This decodes that inner
// string.
//
// One pass over a char-code array, no backtracking, minimal allocation: the
// payload grows with home size and an on-device parse that runs too long trips
// the "code took too long to run" watchdog. Malformed input yields null rather
// than throwing.
(:background)
class JsonParser {
    private var _string as String;
    // Char units, not bytes: _position indexes both this and _string.substring, which is
    // character-indexed — a byte array (toUtf8Array) would desync the two on any
    // multi-byte character and corrupt the extracted substring.
    private var _chars as Array<Char>;
    private var _position as Number;
    private var _length as Number;

    function initialize(string as String) {
        _string = string;
        _chars = string.toCharArray();
        _position = 0;
        _length = _chars.size();
    }

    static function parse(string as String) as Object or Null {
        return new JsonParser(string).parseDocument();
    }

    function parseDocument() as Object or Null {
        skipWhitespace();
        var value = parseValue();
        skipWhitespace();
        return _position == _length ? value : null;
    }

    private function parseValue() as Object or Null {
        skipWhitespace();
        if (_position >= _length) {
            return null;
        }
        var char = _chars[_position];
        if (char == 0x7B) { // {
            return parseObject();
        }
        if (char == 0x5B) { // [
            return parseArray();
        }
        if (char == 0x22) { // "
            return parseString();
        }
        if (char == 0x74) { // t
            return parseLiteral("true", true);
        }
        if (char == 0x66) { // f
            return parseLiteral("false", false);
        }
        if (char == 0x6E) { // n
            return parseLiteral("null", null);
        }
        if (char == 0x2D || (char >= 0x30 && char <= 0x39)) { // - or digit
            return parseNumber();
        }
        return null;
    }

    private function valueStartsHere() as Boolean {
        skipWhitespace();
        if (_position >= _length) {
            return false;
        }
        var char = _chars[_position];
        return char == 0x7B || char == 0x5B || char == 0x22 || char == 0x74 || char == 0x66
            || char == 0x6E || char == 0x2D || (char >= 0x30 && char <= 0x39);
    }

    private function parseObject() as Dictionary or Null {
        var out = {} as Dictionary;
        _position++;
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

    private function parseMember(out as Dictionary) as Boolean {
        skipWhitespace();
        if (_position >= _length || _chars[_position] != 0x22) { // "
            return false;
        }
        var key = parseString();
        if (key == null) {
            return false;
        }
        skipWhitespace();
        if (_position >= _length || _chars[_position] != 0x3A) { // :
            return false;
        }
        _position++;
        if (!valueStartsHere()) {
            return false;
        }
        out.put(key, parseValue());
        return true;
    }

    private function parseArray() as Array or Null {
        var out = [] as Array;
        _position++;
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

    private function consumeClose(bracket as Number) as Boolean {
        skipWhitespace();
        if (_position < _length && _chars[_position] == bracket) {
            _position++;
            return true;
        }
        return false;
    }

    private function consumeComma() as Boolean {
        skipWhitespace();
        if (_position < _length && _chars[_position] == 0x2C) { // ,
            _position++;
            return true;
        }
        return false;
    }

    private function parseString() as String or Null {
        _position++;
        var start = _position;
        while (_position < _length) {
            var char = _chars[_position];
            if (char == 0x22) { // "
                var result = _string.substring(start, _position);
                _position++;
                return result;
            }
            if (char == 0x5C) { // \
                return parseEscapedString(start);
            }
            _position++;
        }
        return null;
    }

    private function parseEscapedString(start as Number) as String or Null {
        var result = _string.substring(start, _position) as String;
        while (_position < _length) {
            var char = _chars[_position];
            if (char == 0x22) { // "
                _position++;
                return result;
            }
            if (char != 0x5C) { // \
                var runStart = _position;
                while (_position < _length && _chars[_position] != 0x22 && _chars[_position] != 0x5C) {
                    _position++;
                }
                result += _string.substring(runStart, _position);
                continue;
            }
            _position++;
            if (_position >= _length) {
                return null;
            }
            var escapeCode = _chars[_position];
            if (escapeCode == 0x75) { // u
                var decoded = parseUnicodeEscape();
                if (decoded == null) {
                    return null;
                }
                result += decoded;
            } else {
                result += unescapeSimple(escapeCode.toNumber());
                _position++;
            }
        }
        return null;
    }

    private function unescapeSimple(escapeCode as Number) as String {
        if (escapeCode == 0x6E) { // n
            return "\n";
        }
        if (escapeCode == 0x74) { // t
            return "\t";
        }
        if (escapeCode == 0x72) { // r
            return "\r";
        }
        if (escapeCode == 0x62) { // b
            return "\b";
        }
        if (escapeCode == 0x66) { // f
            return "\f";
        }
        // \" \\ \/ and any other single-char escape: the char stands for itself.
        return _string.substring(_position, _position + 1) as String;
    }

    private function parseUnicodeEscape() as String or Null {
        if (_position + 4 >= _length) {
            return null;
        }
        var code = 0;
        for (var i = 1; i <= 4; i++) {
            var digit = parseHexDigit(_chars[_position + i].toNumber());
            if (digit < 0) {
                return null;
            }
            code = (code << 4) | digit;
        }
        _position += 5;
        return codePointToString(code);
    }

    private function parseHexDigit(char as Number) as Number {
        if (char >= 0x30 && char <= 0x39) { // 0-9
            return char - 0x30;
        }
        if (char >= 0x41 && char <= 0x46) { // A-F
            return char - 0x37;
        }
        if (char >= 0x61 && char <= 0x66) { // a-f
            return char - 0x57;
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

    private function parseNumber() as Object or Null {
        var start = _position;
        var hasDot = false;
        var hasExponent = false;
        var previousWasExponent = false;
        if (_position < _length && _chars[_position] == 0x2D) { // -
            _position++;
        }
        while (_position < _length) {
            var char = _chars[_position];
            var isExponent = false;
            if (char >= 0x30 && char <= 0x39) {
            } else if (char == 0x2E && !hasDot && !hasExponent) { // .
                hasDot = true;
            } else if ((char == 0x65 || char == 0x45) && !hasExponent) { // e E
                hasExponent = true;
                isExponent = true;
            } else if ((char == 0x2B || char == 0x2D) && previousWasExponent) { // + -
            } else {
                break;
            }
            previousWasExponent = isExponent;
            _position++;
        }
        if (_position == start) {
            return null;
        }
        var text = _string.substring(start, _position);
        if (text == null) {
            return null;
        }
        if (!hasDot && !hasExponent) {
            var asNumber = text.toNumber();
            if (asNumber != null) {
                return asNumber;
            }
        }
        return text.toFloat();
    }

    private function parseLiteral(word as String, value as Object or Null) as Object or Null {
        var chars = word.toUtf8Array();
        if (_position + chars.size() > _length) {
            return null;
        }
        for (var i = 0; i < chars.size(); i++) {
            if (_chars[_position + i] != chars[i]) {
                return null;
            }
        }
        _position += chars.size();
        return value;
    }

    private function skipWhitespace() as Void {
        while (_position < _length) {
            var char = _chars[_position];
            if (char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D) {
                _position++;
            } else {
                return;
            }
        }
    }
}
