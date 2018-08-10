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
    case variable(Token)
    /**
     A function defined directly as a value, without a name being given. The `id`
     value uniquely identifies this function among any others defined in the
     program.
     */
    case anonFunction(id: Int, parameters: [Token], body: [Statement])
    /**
     An expression invoking a function.
     - remark: The closing parenthesis of the arguments list is held for
     error reporting.
     */
    case call(Expression, paren: Token, arguments: [Expression])
    /** An expression of a unary operator applied to another expresssion. */
    case unary(op: Token, Expression)
    /** An expression with two subexpressions composed with an operator. */
    case binary(left: Expression, op: Token, right: Expression)
    /** An expression binding a new value to a variable. */
    case assignment(name: Token, value: Expression)
    /** An expression combining two subexpressions with a logical operator. */
    case logical(left: Expression, op: Token, right: Expression)
}

/** An element of Lox grammar that produces an effect. */
enum Statement : Equatable
{
    /** A statement declaring a named function. */
    indirect case functionDecl(identifier: Token, parameters: [Token], body: [Statement])
    /** A statement declaring a variable. An initial value may be provided. */
    case variableDecl(name: Token, initializer: Expression?)
    /** A statment consisting of an expression. */
    case expression(Expression)
    /** A statement that conditionally executes a set of other statements. */
    indirect case conditional(Expression, then: Statement, else: Statement?)
    /** A statement for displaying an expression as output to the user. */
    case print(Expression)
    /** A statement providing the final value of a function invocation. */
    case `return`(Token, value: Expression?)
    /**
     A statement that repeatedly executes a substatement (usually a block) until a
     condition evaluates to false.
     */
    indirect case loop(condition: Expression, body: Statement)
    /**
     A statement that immediately moves control to the end of the innermost
     enclosing loop.
     */
    case breakLoop;
    /** A brace-enclosed series of other statements. */
    indirect case block([Statement])
}
