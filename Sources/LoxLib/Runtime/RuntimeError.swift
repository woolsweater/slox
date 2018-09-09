import Foundation

/** A failure that occurs during interpretation of a program. */
struct RuntimeError : Error
{
    /** The token that was being evaluated when the error was detected. */
    let token: Token
    /** A user-facing explanation for the failure. */
    let message: String
}

extension RuntimeError
{
    /**
     There was an attempt to read from or write to a name that does not exist in any
     reachable scope.
     */
    static func undefined(_ name: Token) -> RuntimeError
    {
        return RuntimeError(token: name,
                          message: "Name '\(name.lexeme)' is not defined")
    }

    /**
     There was an attempt to read the value of a variable that had never been assigned
     a value.
     */
    static func uninitialized(_ variable: Token) -> RuntimeError
    {
        return RuntimeError(token: variable,
                          message: "Variable '\(variable.lexeme)' used before being initialized")
    }

    /** Found a non-numeric operand in an arithmetic context. */
    static func numeric(at token: Token) -> RuntimeError
    {
        return RuntimeError(token: token, message: "Operand must be a number")
    }

    /** The `callee` of a `.call` expression did not evaluate to an invokable value. */
    static func notCallable(at token: Token) -> RuntimeError
    {
        return RuntimeError(token: token, message: "Can only invoke functions/methods and classes")
    }

    /** The parameter count of an invoked function did not match the number of arguments. */
    static func arityMismatch(at token: Token, arity: Int, argCount: Int) -> RuntimeError
    {
        return RuntimeError(token: token, message: "Expected \(arity) arguments, have \(argCount)")
    }

    /** A variable expression lookup failed. */
    static func unresolvedVariable(_ variable: Token) -> RuntimeError
    {
        return RuntimeError(token: variable,
                          message: "Variable '\(variable.lexeme)' could not be resolved")
    }

    /** The object of a member access expression (get or set) was not a Lox object. */
    static func notAnObject(at token: Token) -> RuntimeError
    {
        return RuntimeError(token: token,
                          message: "Target of member access is not an object")
    }

    /** The name given in a member access was not found on the object. */
    static func unrecognizedMember(_ token: Token) -> RuntimeError
    {
        return RuntimeError(token: token,
                          message: "No member named '\(token.lexeme)'")
    }
}
