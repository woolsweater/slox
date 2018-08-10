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

    //TODO: This doesn't handle statements at all.

    private func render(_ expression: Expression) -> String
    {
        switch expression {
            case let .literal(value):
                return value.description
            case let .grouping(subexpression):
                return self.parenthesize("G", subexpression)
            case let .variable(name):
                return "${\(name.lexeme)}"
            case let .anonFunction(id: id, parameters: _, body: _):
                return self.parenthesize("<fn __unnamedFunc\(id)>")
            case let .call(callee, paren: _, arguments: arguments):
                return self.renderCall(to: callee, arguments: arguments)
            case let .unary(op: op, subexpression):
                return self.parenthesize(op.lexeme, subexpression)
            case let .binary(left: leftSubexpression, op: op, right: rightSubexpression):
                return self.parenthesize(op.lexeme, leftSubexpression, rightSubexpression)
            case let .assignment(name: name, value: value):
                return self.parenthesize("SET ${\(name.lexeme)}", value)
            case let .logical(left: leftSubexpression, op: op, right: rightSubexpression):
                return self.parenthesize(op.lexeme, leftSubexpression, rightSubexpression)
        }
    }

    private func renderCall(to callee: Expression, arguments: [Expression]) -> String
    {
        let template = "(<call> \(self.render(callee)) [%@])"
        guard let first = arguments.first else {
            return String(format: template, "")
        }
        let argList = arguments.dropFirst().reduce(into: "\(self.render(first))") {
            (list, next) in list += ", \(self.render(next))"
        }

        return String(format: template, argList)
    }

    private func parenthesize(_ name: String, _ exprs: Expression...) -> String
    {
        let description = exprs.reduce(into: "\(name)") {
            (string, next) in string += " \(self.render(next))"
        }
        return "(" + description + ")"
    }
}
