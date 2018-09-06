import Foundation

/** A common lexical error for which Lox can provide specific guidance. */
struct Typo
{
    /** The source content of the erroneous code. */
    let lexeme: String
    /** A description of the mistake, for display to the user. */
    let message: String
}

extension Typo
{
    /** The user has typed "func" instead of "fun" in a function declaration. */
    static let `func` = Typo(lexeme: "func",
                            message: "'func' is not a keyword; did you mean 'fun'?")
}
