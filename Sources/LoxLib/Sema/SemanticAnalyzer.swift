import Foundation

/**
 Performs an examination of the AST, without executing it. It may produce
 diagnostics, information for the interpreter, or anything else that can
 be computed statically.
 */
protocol SemanticAnalyzer : AnyObject
{
    /**
     Examine the given statement, recursing as needed into subcomponents.
     - throws: May throw a `SemanticError`, if necessary, to signal a condition that should
     prevent execution.
     */
    func analyze(_ statement: Statement) throws
}

/**
 A failure that occurs during static analysis of a program and which should prevent the
 program from being executed.
 */
struct SemanticError : Error
{
    /** The token at which the error occurred. */
    let token: Token
    /** A user-facing description of the error. */
    let message: String
}

/**
 An unexpected condition detected during static analysis that is likely to
 represent a mistake by the user, but does not prevent program execution.
 */
struct SemanticWarning : Error
{
    /** The token at which the problem was detected. */
    let token: Token
    /** A user-facing string describing the problem. */
    let message: String
}

/**
 A collection of warnings that were all produced by analysis of a single
 statement.
 */
struct SemanticBlockWarning : Error
{
    let warnings: [SemanticWarning]
}
