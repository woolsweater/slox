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
     prevent further analysis and execution.
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
