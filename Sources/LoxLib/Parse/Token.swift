import Foundation

/** The runtime value of a literal value found in the source code. */
enum LiteralValue : Equatable
{
    /** A number literal. */
    case double(Double)
    /** A string literal. */
    case string(String)
    /** A boolean literal. */
    case bool(Bool)
    /** A literal representing an absent value in the program.  */
    case `nil`
}

/** An atomic Lox language entity, produced by scanning Lox source. */
struct Token : Equatable
{
    /** The nature of this `Token`. */
    let kind: Kind
    /** The raw source text that produced this `Token`. */
    let lexeme: String
    /** The simple runtime value that the `Token` represents. */
    let literal: LiteralValue?
    /** The line in the source file on which the `Token` was scanned. */
    let line: Int
}

extension Token
{
    /**
     The basic role of a `Token`, including specific punctuation, keywords,
     operators, and so on.
     */
    enum Kind : Equatable
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
        case and, `break`, `class`, `else`, `false`, fun, `for`, `if`, `nil`, or
        case print, `return`, `super`, this, `true`, unless, until, `var`, `while`

        case EOF
    }
}

extension Token.Kind
{
    /**
     If the given source string represents a Lox keyword, return the appropriate `Kind`,
     else `nil`.
     */
    init?(keyword: String)
    {
        switch keyword {
            case "and": self = .and
            case "break": self = .break
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
            case "unless": self = .unless
            case "until": self = .until
            case "var": self = .var
            case "while": self = .while
            default:
                return nil
        }
    }
}

extension LiteralValue
{
    /** User-facing representation of the literal. */
    var description: String
    {
        switch self {
            case let .string(string): return string
            case let .double(double): return double.description
            case let .bool(bool): return bool.description
            case .nil: return "nil"
        }
    }
}

extension Token
{
    /** A `Token` representing the end of a source file. */
    static func eof(_ line: Int) -> Token
    {
        return Token(kind: .EOF, lexeme: "", literal: nil, line: line)
    }

    /**
     A synthesized token for references to an object within that
     object's methods.
     */
    static func this(at line: Int) -> Token
    {
        return Token(kind: .this, lexeme: "this", literal: nil, line: line)
    }

    /** Printable rendering of the `Token` for debugging. */
    var description: String
    {
        return "\(self.kind) \(self.lexeme) \(self.literal?.description ?? "")"
    }
}
