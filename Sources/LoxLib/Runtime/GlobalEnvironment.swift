import Foundation

/**
 Top-level environment for an `Interpreter`. Keeps a mapping of builtins and
 other global variables to their values.
 */
class GlobalEnvironment
{
    /** The collection of globally-available names and values. */
    private var values : [String : LoxValue?] = [:]

    init() {}

    /**
     Add an value to the global environment, with the given name.
     - parameter name: The identifier for the object.
     - parameter value: The initial value; pass `nil` for a variable declaration
     with no initializer expression.
     - remark: This is also permitted to assign a new value to an
     existing varaible.
     */
    func define(name: String, value: LoxValue?)
    {
        self.values[name] = value
    }

    /** Register a builtin function. */
    func defineBuiltin(_ callable: Callable)
    {
        let value = LoxValue.callable(callable)
        self.define(name: callable.name, value: value)
    }

    /**
     Look up the value of the given name.
     - returns: The assigned value, or `nil` if the name is unknown.
     - throws: A `RuntimeError` if the name was declared but never
     assigned a value.
     */
    func read(name: Token) throws -> LoxValue?
    {
        guard let lookup = self.lookUpValue(of: name) else {
            return nil
        }

        guard let value = lookup else {
            throw RuntimeError.uninitialized(name)
        }

        return value
    }

    /**
     Bind the given name to the new value.
     - throws: A `RuntimeError` if the name has not been globally declared.
     */
    func assign(name: Token, value: LoxValue) throws
    {
        guard self.setValue(value, forName: name.lexeme) else {
            throw RuntimeError.undefined(name)
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
    func updateCut(value: LoxValue) throws
    {
        guard self.setValue(value, forName: ReplSupport.cut) else {
            throw RuntimeError.missingCut
        }
    }

    //MARK:- Internal

    /**
     Look up the value represented by the given token.
     - returns: The variable's value if lookup succeeds, else `nil`. Note that
     the value itself may also be `nil`, if the name has been declared but not
     assigned a value.
     */
    private func lookUpValue(of name: Token) -> LoxValue??
    {
        return self.values[name.lexeme]
    }

    /**
     Look up the given name. If found, update its value.
     - returns: `true` if the update succeeds, else `false`
     */
    private func setValue(_ value: LoxValue, forName name: String) -> Bool
    {
        guard self.values.keys.contains(name) else {
            return false
        }

        self.values[name] = value
        return true
    }
}

private extension RuntimeError
{
    static let missingCut = RuntimeError(
        token: Token(kind: .identifier, lexeme: ReplSupport.cut, literal: nil, line: 1),
        message: "'_' does not exist in the current context"
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
