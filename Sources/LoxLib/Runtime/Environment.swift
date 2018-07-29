import Foundation

/** Runtime environment for an `Interpreter`. */
class Environment
{
    private var values : [String : Any?] = [:]

    func define(name: String, value: Any?)
    {
        // Redefinition of variables is permitted
        self.values[name] = value
    }

    func read(variable: Token) throws -> Any?
    {
        guard let value = self.values[variable.lexeme] else {
            throw RuntimeError.undefined(variable)
        }

        return value
    }

    func assign(variable: Token, value: Any?) throws
    {
        let name = variable.lexeme
        guard self.values.keys.contains(name) else {
            throw RuntimeError.undefined(variable)
        }

        self.values[name] = value
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
