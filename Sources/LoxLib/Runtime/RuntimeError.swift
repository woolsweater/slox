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
        return RuntimeError(token: token, message: "Expected \(arity) arguments, have \(argCount).")
    }
}
