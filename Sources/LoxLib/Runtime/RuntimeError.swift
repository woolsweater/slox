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
        return RuntimeError(token: token, message: "Can only invoke functions and classes")
    }

    /** The parameter count of an invoked function did not match the number of arguments. */
    static func arityMismatch(at token: Token, arity: Int, argCount: Int) -> RuntimeError
    {
        return RuntimeError(token: token, message: "Expected \(arity) arguments, have \(argCount)")
    }

    /**
     A variable expression lookup failed.
     - remark: This represents a bug in the analyzer. We need to halt interpretation
     even in non-debug builds.
     */
    static func unresolvedVariable(_ variable: Token) -> RuntimeError
    {
        return RuntimeError(token: variable,
                            message: "Variable '\(variable.lexeme)' could not be resolved")
    }
}
