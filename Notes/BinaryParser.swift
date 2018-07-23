// Another way to write binary parser boilerplate,
// with a struct type

struct Token {
    enum Kind {
        case star
        case plus
        case less
        case equalEqual
        case bangEqual
        case EOF
    }

    let kind: Kind
}

extension Token {
    static let eof = Token(kind: .EOF)
}

indirect enum Expression {
    case literal(String)
    case binary(left: Expression, op: Token, right: Expression)
    // Result of an error production in the grammar
    case error(at: Token, message: String, remainder: Expression)
}

typealias Parsing = (inout [Token]) -> Expression

struct BinaryParser {
    private let ops: [Token.Kind]
    private let nextParser: Parsing

    init(ops: [Token.Kind], followedBy: @escaping Parsing) {
        self.ops = ops
        self.nextParser = followedBy
    }

    func parse(_ tokens: inout [Token]) -> Expression {
        guard self.matchOps(&tokens) == nil else {
            return .error(at: tokens.first!,
                     message: "missing left operand",
                   remainder: self.parse(&tokens))
        }

        return self.parseAfterErrors(&tokens)
    }

    private func parseAfterErrors(_ tokens: inout [Token]) -> Expression {
        var expr = self.nextParser(&tokens)

        while let op = self.matchOps(&tokens) {
            let right = nextParser(&tokens)
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func matchOps(_ tokens: inout [Token]) -> Token? {
        guard
            let opToken = tokens.first,
            self.ops.contains(where: { opToken.kind == $0 })
        else { return nil }

        tokens = Array(tokens.dropFirst())
        return opToken
    }
}

let multiplication = BinaryParser(ops: [.star], followedBy: { (_) in .literal("") })
let addition = BinaryParser(ops: [.plus], followedBy: multiplication.parse)
let comparison = BinaryParser(ops: [.less], followedBy: addition.parse)
let equality = BinaryParser(ops: [.equalEqual, .bangEqual], followedBy: comparison.parse)
let expression = { (tokens) in equality.parse(&tokens) }

func checkErrors(in expression: Expression) {
    if case let .error(at: token, message: message, remainder: remainder) = expression {
        reportError(at: token, message: message)
        checkErrors(in: remainder)
    }
}

func reportError(at token: Token, message: String) {}
