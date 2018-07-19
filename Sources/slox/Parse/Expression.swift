/**
 A type that will transform some `Expression` into a `Result`;
 usually this means a recursive walk of nested `Expression`s.
 */
protocol ExpressionReader
{
    /** The product of this visitor's transform. */
    associatedtype Result

    /**
     Examine the given expression and produce the appropriate
     `Result` value. If the expression has sub-expressions, they
     will be incorporated in the result.
     */
    func read(_ expression: Expression) -> Result
}

/** An element of Lox grammar. */
indirect enum Expression
{
    /** A "primary" expression that consists of a single value. */
    case literal(LiteralValue)
    /** An expression of a unary operator applied to another expresssion. */
    case unary(op: Token, Expression)
    /** An expression with two subexpressions composed with an operator. */
    case binary(left: Expression, op: Token, right: Expression)
    /** An expression that was set off by parentheses in the source code. */
    case grouping(Expression)
}
