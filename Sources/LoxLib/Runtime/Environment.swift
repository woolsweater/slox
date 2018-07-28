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
        let name = variable.lexeme
        guard let value = self.values[name] else {
            throw RuntimeError(token: variable, message: "Name '\(name)' is not defined")
        }

        return value
    }
}
