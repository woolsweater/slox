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
    func visit(_ unary: Unary) -> Result
    func visit(_ binary: Binary) -> Result
    func visit(_ grouping: Grouping) -> Result
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

struct Unary : Expr
{
    let op: Token
    let expr: Expr
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}

struct Binary : Expr
{
    let left: Expr
    let op: Token
    let right: Expr
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}

struct Grouping : Expr
{
    let expr: Expr
    
    func accept<V : ExprVisitor>(visitor: V) -> V.Result
    {
        return visitor.visit(self)
    }
}
