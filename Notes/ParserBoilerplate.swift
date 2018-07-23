// Reduce parser boilerplate with a parser-making function,
// `binaryParser(followedBy:ops:)`
//
// Is this a combinator?

struct Token {
    enum Kind {
        case star
        case plus
        case less
        case equalEqual
        case bangEqual
    }

    let kind: Kind
}

protocol Expr {}

struct Literal : Expr {}

struct Binary : Expr {
    let left: Expr
    let op: Token
    let right: Expr
}

// inout will be unnecessary if this is in a Parser class that's tracking
// parse state/index
typealias Parser = (inout [Token]) -> Expr

func binaryParser(followedBy nextParser: @escaping Parser, ops: Token.Kind...) -> Parser {
    return { (tokens) in
        var expr = nextParser(&tokens)

        while let op = matchAny(&tokens, ops) {
            let right = nextParser(&tokens)
            expr = Binary(left: expr, op: op, right: right)
        }

        return expr
    }
}

func binaryParserWithError(followedBy nextParser: @escaping Parser, ops: Token.Kind...) -> Parser {
    var production: Parser!

    let errorProduction: Parser = { [production] (tokens: inout [Token]) in
        guard matchAny(&tokens, ops) == nil else {
            // Report error
            return production!(&tokens)
        }

        var expr = nextParser(&tokens)

        while let op = matchAny(&tokens, ops) {
            let right = nextParser(&tokens)
            expr = Binary(left: expr, op: op, right: right)
        }

        return expr
    }

    production = { (tokens: inout [Token]) in
        return errorProduction(&tokens)
    }

    return production
}

func matchAny(_ tokens: inout [Token], _ ops: [Token.Kind]) -> Token? {
    guard
        let op = tokens.first,
        ops.contains(where: { op.kind == $0 })
    else { return nil }

    tokens = Array(tokens.dropFirst())
    return op
}

let mulitplication = binaryParser(followedBy: { (_) in Literal() }, ops: .star)
let addition = binaryParser(followedBy: mulitplication, ops: .plus)
let comparison = binaryParser(followedBy: addition, ops: .less)
let equality = binaryParser(followedBy: comparison, ops: .equalEqual, .bangEqual)
let expression = { (tokens) in equality(&tokens) }
