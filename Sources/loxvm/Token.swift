/** An atomic Lox language entity, produced by scanning Lox source. */
struct Token
{
    /** The nature of this token. */
    let kind: Kind
    /** The raw source text that produced this token */
    let lexeme: Substring
    /** The line in the source file on which the token was scanned. */
    let lineNumber: Int
}

extension Token
{
    /**
     The basic role of a `Token`, including specific punctuation, keywords,
     operators, and so on.
     */
    enum Kind : Equatable
    {
        // Single-character punctuation
        case leftParen, rightParen, leftBrace, rightBrace
        case colon, comma, dot, semicolon
        case minus, plus, slash, star

        // Single- and double-character punctuation
        case arrow, bang, bangEqual, equal, equalEqual
        case greater, greaterEqual, less, lessEqual

        // Literals
        case identifier, string, number

        // Keywords
        case and, `break`, `class`, `continue`, `else`, `false`, finally, `for`
        case fun, `if`, match, `nil`, or, print, `return`, `super`, this
        case `true`, unless, until, `var`, `while`

        case EOF

        /**
         A meta-token that represents a parse failure. The `lexeme` value in this case will be
         a user-readable description of the problem.
         */
        case error
    }
}
