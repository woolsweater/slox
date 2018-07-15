// Should consider moving Exprs to be enum cases;
// this would eliminate some of the complexity with the visitor and
// probably remove the need to do code generation.
// In fact, the visitor isn't really even a visitor. Should rename.

enum LiteralValue {
    case double(Double)
    case string(String)
}

extension LiteralValue {
    var description: String {
        switch self {
            case let .string(string): return string
            case let .double(double): return "\(double)"
        }
    }
}

struct Token {
    let lexeme: String
}

protocol ExpressionVisitor {
    associatedtype Result

    func visit(_ expression: Expression) -> Result
}

indirect enum Expression {
    case literal(LiteralValue)
    case unary(op: Token, Expression)
    case binary(left: Expression, op: Token, right: Expression)
    case grouping(Expression)
    case this(keyword: Token)
}

class AstParenRenderer : ExpressionVisitor {
    private let ast: Expression

    init(ast: Expression) {
        self.ast = ast
    }

    func renderAst() -> String {
        return self.visit(self.ast)
    }

    func visit(_ expression: Expression) -> String {
        switch expression {
            case let .literal(value):
                return value.description
            case let .unary(op: op, expression):
                return self.parenthesize(op.lexeme, expression)
            case let .binary(left: left, op: op, right: right):
                return self.parenthesize(op.lexeme, left, right)
            case let .grouping(expression):
                return self.parenthesize("G", expression)
        }
    }

    private func parenthesize(_ name: String, _ expressions: Expression...) -> String
    {
        let description = expressions.reduce(into: "\(name)") {
            (string, next) in string += " \(self.visit(next))"
        }
        return "(" + description + ")"
    }
}

let ast: Expression = .binary(
    left:
        .unary(op: Token(lexeme: "-"),
               .literal(.double(123))),
    op: Token(lexeme: "*"),
    right: .grouping(.literal(.double(45.67)))
)

let renderer = AstParenRenderer(ast: ast)
print(renderer.renderAst())
