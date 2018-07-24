@testable import LoxLib

extension Token.Kind
{
    /**
     Given a punctuation `Kind`, return the represented string.
     */
    var lexeme: String
    {
        switch self {
            case .leftParen: return "("
            case .rightParen: return ")"
            case .comma: return ","
            case .minus: return "-"
            case .plus: return "+"
            case .slash: return "/"
            case .star: return "*"
            case .equalEqual: return "=="
            case .bangEqual: return "!="
            default:
                fatalError("Not implemented yet")
        }
    }
}

extension Token
{
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
}
