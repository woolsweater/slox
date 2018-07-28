@testable import LoxLib

extension Token.Kind
{
    /**
     Given a `Kind` with a single possible `String` value,
     return the represented string.
     */
    var lexeme: String
    {
        switch self {
            // Punctuation
            case .leftParen: return "("
            case .rightParen: return ")"
            case .comma: return ","
            case .minus: return "-"
            case .plus: return "+"
            case .slash: return "/"
            case .star: return "*"
            case .bang: return "!"
            case .equalEqual: return "=="
            case .bangEqual: return "!="
            // Keywords
            case .false: return "false"
            case .true: return "true"
            case .nil: return "nil"
            default:
                fatalError("Not implemented yet: \(self)")
        }
    }
}

extension Token
{
    static let leftParen = Token(punctuation: .leftParen)
    static let rightParen = Token(punctuation: .rightParen)

    init(string: String, at line: Int = 1)
    {
        self.init(kind: .string,
                lexeme: string,
               literal: .string(string),
                  line: line)
    }

    init(number: Double, at line: Int = 1)
    {
        self.init(kind: .number,
                lexeme: String(number),
               literal: .double(number),
                  line: line)
    }

    init(punctuation: Kind, at line: Int = 1)
    {
        self.init(kind: punctuation,
                lexeme: punctuation.lexeme,
               literal: nil,
                  line: line)
    }

    init(keyword: Kind, at line: Int = 1)
    {
        self.init(kind: keyword,
                lexeme: keyword.lexeme,
               literal: nil,
                  line: line)
    }
}
