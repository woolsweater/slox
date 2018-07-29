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
     scope and then looking in enclosing scopes, in order.
     - throws: A `RuntimeError` if the variable is not visible in any
     reachable scope.
     - returns: The innermost value of the variable.
     */
    func read(variable: Token) throws -> Any?
    {
        guard let value = self.lookUpValue(of: variable) else {
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
        guard self.setValue(value, forName: name) else {
            throw RuntimeError.undefined(variable)
        }
    }

    //MARK:- REPL support

    /**
     Define a special variable named '_' that the interpreter will use to store
     the result of the last evaluated expression.
     - remark: This should only be used when the interpreter is running in a
     REPL context. Note that we do not try to prevent the user from overwriting
     or shadowing the variable, since it can also be used in scripts.
     */
    func createCut()
    {
        self.define(name: ReplSupport.cut, value: nil)
    }

    /**
     Set the value of the special '_' variable to the given new value.
     - remark: It is an error to try to update the value without having called
     `createCut()` first.
     */
    func updateCut(value: Any?) throws
    {
        guard self.setValue(value, forName: ReplSupport.cut) else {
            throw RuntimeError.missingCut
        }
    }

    //MARK:- Internal

    /**
     Look up the variable represented by the given token in this scope and
     any enclosing scopes.
     - returns: The variable's value if lookup succeeds, else `nil`.
     */
    private func lookUpValue(of variable: Token) -> Any??
    {
        return self.values[variable.lexeme] ??
                self.enclosing?.lookUpValue(of: variable)
    }

    /**
     Look up the named variable in this scope and any enclosing scopes. If
     found, update its value.
     - returns: `true` if the update succeeds, else `false`
     */
    private func setValue(_ value: Any?, forName name: String) -> Bool
    {
        guard self.values.keys.contains(name) else {
            guard let enclosing = self.enclosing else {
                return false
            }
            return enclosing.setValue(value, forName: name)
        }

        self.values[name] = value
        return true
    }
}

private extension RuntimeError
{
    static func undefined(_ variable: Token) -> RuntimeError
    {
        return RuntimeError(token: variable,
                          message: "Name '\(variable.lexeme)' is not defined")
    }

    static let missingCut = RuntimeError(
        token: Token(kind: .identifier, lexeme: ReplSupport.cut, literal: nil, line: 1),
        message: "'_' does not exist outside of REPL context"
    )
}

private struct ReplSupport
{
    /**
     Name of the special variable in a REPL context that holds the last result of
     an expression evaluation.
     */
    static let cut = "_"
}
