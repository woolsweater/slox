import Foundation

/** Runtime environment for an `Interpreter`. */
class Environment
{
    private var values : [String : Any?] = [:]

    private let enclosing : Environment?

    init(enclosing: Environment? = nil)
    {
        self.enclosing = enclosing
    }

    func define(name: String, value: Any?)
    {
        // Redefinition of variables is permitted
        self.values[name] = value
    }

    func read(variable: Token) throws -> Any?
    {
        guard let value = self.readAllScopes(toFind: variable) else {
            throw RuntimeError.undefined(variable)
        }

        return value
    }

    func assign(variable: Token, value: Any?) throws
    {
        let name = variable.lexeme
        guard self.values.keys.contains(name) else {
            guard let enclosing = self.enclosing else {
                throw RuntimeError.undefined(variable)
            }
            try enclosing.assign(variable: variable, value: value)
            return
        }

        self.values[name] = value
    }

    private func readAllScopes(toFind variable: Token) -> Any?
    {
        return self.values[variable.lexeme] ??
                self.enclosing?.readAllScopes(toFind: variable)
    }
}

private extension RuntimeError
{
    static func undefined(_ variable: Token) -> RuntimeError
    {
        return RuntimeError(token: variable,
                          message: "Name '\(variable.lexeme)' is not defined")
    }
}
