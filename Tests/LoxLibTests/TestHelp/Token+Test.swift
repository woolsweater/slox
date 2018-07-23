@testable import LoxLib

extension Token.Kind
{
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
            default:
                fatalError("Not implemented yet")
        }
    }
}

extension Token
{
    init(string: String)
    {
        self.init(kind: .string,
                lexeme: string,
               literal: .string(string),
                  line: 1)
    }

    init(number: Double)
    {
        self.init(kind: .number,
                lexeme: String(number),
               literal: .double(number),
                  line: 1)
    }

    init(punctuation: Kind)
    {
        let lexeme = punctuation.lexeme
        self.init(kind: punctuation, lexeme: lexeme, literal: nil, line: 1)
    }
}
