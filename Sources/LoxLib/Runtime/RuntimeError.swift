import Foundation

/** A failure that occurs during interpretation of a program. */
struct RuntimeError : Error
{
    /** The token that was being evaluated when the error was detected. */
    let token: Token
    /** A user-facing explanation for the failure. */
    let message: String
}
