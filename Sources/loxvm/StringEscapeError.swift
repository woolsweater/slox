import Foundation

/**
 An error that occurred while processing an escape sequence in
 a string.
 */
protocol StringEscapeError : Error
{
    /** Information about the error to be used in compiler output. */
    var message: String { get }
}

/**
 A backslash was followed by a character that is not one of Lox's
 valid escape characters; for example, `\g`.
 */
struct UnrecognizedEscape : StringEscapeError
{
    let character: Character
    var message: String { "Unrecognized escape character '\(self.character)'" }

    init(codeUnit: UInt8) { self.character = Character(UnicodeScalar(codeUnit)) }
}

/**
 A Unicode escape was successfully parsed but the value does not
 represent a usable codepoint.
 */
struct InvalidCodepoint : StringEscapeError
{
    enum Reason
    {
        case surrogate, outOfRange

        fileprivate var rendered: String
        {
            switch self {
                case .surrogate: return "a UTF-16 surrogate codepoint"
                case .outOfRange: return "out of range"
            }
        }
    }

    let codepoint: UInt32
    let reason: Reason

    var message: String { "Codepoint U+\(String(format: "%X", self.codepoint)) is \(self.reason.rendered)" }

    init(codepoint: UInt32, reason: Reason)
    {
        self.codepoint = codepoint
        self.reason = reason
    }
}

/** A Unicode escape was missing its terminator. */
struct UnterminatedUnicode : StringEscapeError
{
    let lastCharacter: Character
    var message: String { "Expected ';' to terminate Unicode escape but found '\(self.lastCharacter)'" }

    init(codeUnit: UInt8) { self.lastCharacter = Character(UnicodeScalar(codeUnit)) }
}

/**
 The first character of a Unicode escape sequence was not a
 hexadecimal digit.
 */
struct UnicodeInitialNonHex : StringEscapeError
{
    let character: Character
    var message: String { "Expected hexadecimal digit to start Unicode escape but found '\(self.character)'" }

    init(codeUnit: UInt8) { self.character = Character(UnicodeScalar(codeUnit)) }
}
