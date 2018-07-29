import Foundation

/** An element of Lox grammar that produces a value. */
indirect enum Expression : Equatable
{
    /** A "primary" expression that consists of a single value. */
    case literal(LiteralValue)
    /** An expression that was set off by parentheses in the source code. */
    case grouping(Expression)
    /**
     An expression referring to a variable, that evaluates to the variable's
     stored value.
     */
    case variable(name: Token)
    /** An expression of a unary operator applied to another expresssion. */
    case unary(op: Token, Expression)
    /** An expression with two subexpressions composed with an operator. */
    case binary(left: Expression, op: Token, right: Expression)
    /** An expression binding a new value to a variable. */
    case assignment(name: Token, value: Expression)
}

enum Statement : Equatable
{
    /** A statement declaring a variable. An initial value may be provided. */
    case variableDecl(name: Token, initializer: Expression?)
    /** A statment consisting of an expression. */
    case expression(Expression)
    /** A statement for displaying an expression as output to the user. */
    case print(Expression)
}
