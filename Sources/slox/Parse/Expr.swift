//////
// AUTOGENERATED FILE DO NOT EDIT
//////

/**
 A type that will transform some `Expr` into a `Result`; usually this
 means a recursive walk of nested `Expr`s.
 */
protocol ExprVisitor
{
    /** The product of this visitor's transform. */
    associatedtype Result
    func visit(_ literal: Literal) -> Result
    func visit<E>(_ unary: Unary<E>) -> Result
    func visit<L, R>(_ binary: Binary<L, R>) -> Result
    func visit<E>(_ grouping: Grouping<E>) -> Result
}

/** A syntactic element in a Lox program. */
protocol Expr
{
    /** Allow the given visitor to transform this value. */
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
}

struct Literal : Expr
{
    let value: LiteralValue
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}

struct Unary<E : Expr> : Expr
{
    let op: Token
    let expr: E
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}

struct Binary<L : Expr, R : Expr> : Expr
{
    let left: L
    let op: Token
    let right: R
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}

struct Grouping<E : Expr> : Expr
{
    let expr: E
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}
