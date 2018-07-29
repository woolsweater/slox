import Foundation

/**
 Runtime environment for an `Interpreter`. Keeps a mapping of variables
 to their values, and a reference to the next outer scope.
 Assignments and lookups are deferred to enclosing scopes if they fail
 in the current one.
 */
class Environment
{
    /**
     The scope that existed just before this one became active. If a
     lookup fails in the current scope, it is retried recursively
     outwards, via this reference.
     */
    let enclosing : Environment?

    /** The collection of variables and values defined in this scope. */
    private var values : [String : Any?] = [:]

    /** Create an environment nested inside the given one. */
    init(nestedIn: Environment? = nil)
    {
        self.enclosing = nestedIn
    }

    /**
     Add a variable to the environment, with the given value.
     - remark: This is also permitted to assign a new value to an
     existing varaible.
     */
    func define(name: String, value: Any?)
    {
        self.values[name] = value
    }

    /**
     Look up the value of the given variable, starting in the current
     scope and then looking in outer scopes in order.
     - throws: A `RuntimeError` if the variable is not visible in any
     reachable scope.
     */
    func read(variable: Token) throws -> Any?
    {
        guard let value = self.readAllScopes(toFind: variable) else {
            throw RuntimeError.undefined(variable)
        }

        return value
    }

    /**
     Bind the given variable to the new value. The variable must exist
     in one of the scope reachable from this one.
     - throws: A `RuntimeError` if the variable is not visible in any
     reachable scope.
     */
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
