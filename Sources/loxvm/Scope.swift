/**
 The level of nesting during compilation, for purposes of variable definition.
 */
enum Scope
{
    /** Top-level, outside of any function or other block. */
    case global

    /**
     Nested in the given number of functions or other blocks.
     - remark: The first scope after `.global` is `.block(1)`, not `.block(0)`.
     */
    case block(Int)
}

extension Scope
{
    /**
     Raise the level of nesting by one. The new count of enclosing blocks is
     returned.
     */
    mutating func increment() -> Int
    {
        let newDepth: Int
        switch self {
            case .global:
                newDepth = 1
            case let .block(depth):
                newDepth = depth + 1
        }

        self = .block(newDepth)

        return newDepth
    }

    /**
     Decrease the level of nesting by one.
     - remark: `.block(1)` decrements to `.global`.
     */
    mutating func decrement()
    {
        switch self {
            case .global:
                fatalError("Internal error: attempt to pop global scope!")
            case .block(0):
                fatalError("Internal error: `.block(0)` is an invalid scope")
            case .block(1):
                self = .global
            case let .block(depth):
                self = .block(depth - 1)
        }
    }
}
