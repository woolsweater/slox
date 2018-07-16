import Foundation

class AstParenRenderer : ExprVisitor
{
    private let ast: Expr

    init(ast: Expr)
    {
        self.ast = ast
    }

    func renderAst() -> String
    {
        return self.ast.accept(visitor: self)
    }

    func visit(_ literal: Literal) -> String
    {
        return literal.value.description
    }

    func visit(_ unary: Unary) -> String
    {
        return self.parenthesize(unary.op.lexeme, unary.expr)
    }

    func visit(_ binary: Binary) -> String
    {
        return self.parenthesize(
            binary.op.lexeme,
            binary.left,
            binary.right
        )
    }

    func visit(_ grouping: Grouping) -> String
    {
        return self.parenthesize("G", grouping.expr)
    }

    private func parenthesize(_ name: String, _ exprs: Expr...) -> String
    {
        let description = exprs.reduce(into: "\(name)") {
            (string, next) in string += " \(next.accept(visitor: self))"
        }
        return "(" + description + ")"
    }
}
