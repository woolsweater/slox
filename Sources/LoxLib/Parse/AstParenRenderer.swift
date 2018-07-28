import Foundation

class AstParenRenderer
{
    private let ast: Expression

    init(ast: Expression)
    {
        self.ast = ast
    }

    func renderAst() -> String
    {
        return self.render(self.ast)
    }

    private func render(_ expression: Expression) -> String
    {
        switch expression {
            case let .literal(value):
                return value.description
            case let .unary(op: op, subexpression):
                return self.parenthesize(op.lexeme, subexpression)
            case let .binary(left: leftSubexpression, op: op, right: rightSubexpression):
                return self.parenthesize(op.lexeme, leftSubexpression, rightSubexpression)
            case let .grouping(subexpression):
                return self.parenthesize("G", subexpression)
        }
    }

    private func parenthesize(_ name: String, _ exprs: Expression...) -> String
    {
        let description = exprs.reduce(into: "\(name)") {
            (string, next) in string += " \(self.render(next))"
        }
        return "(" + description + ")"
    }
}
