import Foundation

struct Token
{
    let kind: Kind
    let lexeme: String
    let literal: Any?
    let line: Int
}

extension Token
{
    enum Kind
    {
        // Single-character punctuation
        case leftParen, rightParen, leftBrace, rightBrace
        case comma, dot, semicolon
        case minus, plus, slash, star

        // Single- and double-character punctuation
        case bang, bangEqual, equal, equalEqual
        case greater, greaterEqual, less, lessEqual

        // Literals
        case identifier, string, number

        // Keywords
        case and, `class`, `else`, `false`, fun, `for`, `if`, `nil`, or
        case print, `return`, `super`, this, `true`, `var`, `while`

        case EOF
    }
}

extension Token.Kind
{
    init?(keyword: String)
    {
        switch keyword {
            case "and": self = .and
            case "class": self = .class
            case "else": self = .else
            case "false": self = .false
            case "fun": self = .fun
            case "for": self = .for
            case "if": self = .if
            case "nil": self = .nil
            case "or": self = .or
            case "print": self = .print
            case "return": self = .return
            case "super": self = .super
            case "this": self = .this
            case "true": self = .true
            case "var": self = .var
            case "while": self = .while
            default:
                return nil
        }
    }
}

extension Token
{
    static func eof(_ line: Int) -> Token
    {
        return Token(kind: .EOF, lexeme: "", literal: nil, line: line)
    }

    var description: String
    {
        return "\(self.kind) \(self.lexeme) \(self.literal ?? "")"
    }
}
