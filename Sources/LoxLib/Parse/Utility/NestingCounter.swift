import Foundation

/** Records levels of nesting of some language construct. */
protocol NestingTracker
{
    /** A description of the language construct that is tracked. */
    associatedtype Kind

    /** Whether any values have been pushed and not yet popped. */
    var isNested: Bool { get }

    /**
     Increment the nesting level by adding the given `value` to the tracker's
     recorded values.
     */
    mutating func push(_ value: Kind)

    /**
     Decrement the nesting level.
     - remark: It is an error to attempt to decrement when there is currently
     no nesting.
     - seealso: The `--` operator.
     */
    mutating func pop()
}

/** Track values of the given `State` through nested scopes. */
struct StateTracker<State> : NestingTracker
    where State : Equatable
{
    /**
     The most recently pushed value. Returns `nil` if there is
     currently no nesting.
     */
    var current: State? { return self.stack.last }

    var isNested: Bool { return !(self.stack.isEmpty) }

    private var stack: [State] = []

    mutating func push(_ value: State) { self.stack.append(value) }
    mutating func pop() { self.stack.removeLast() }
}

/**
 Track a simple nested state that only requires counting, not
 individual values.
 */
struct NestingCounter : NestingTracker
{
    var isNested: Bool { return self.level > 0 }

    private var level = 0

    /**
     Increase the nesting level by 1 regardless of the argument value.
     - remark: Prefer the `inc()` method or `++` operator.
     */
    mutating func push(_ _: Int) { self.level += 1 }

    /**
     Decrease the nesting level by 1.
     - remark: Prefer the `dec()` method or `--` operator.
     */
    mutating func pop()
    {
        guard self.isNested else { fatalError("Not in a nested context") }
        self.level -= 1
    }
}

extension NestingTracker
{
    /**
     Increment the nesting level by pushing the given value.
     */
    static func += (operand: inout Self, value: Kind) { operand.push(value) }

    /**
     Decrement the nesting level.
     - remark: As with `pop()`, it is an error to attempt to decrement when there
     is currently no nesting.
     */
    postfix static func -- (operand: inout Self) { operand.pop() }
}

extension NestingTracker where Kind == Int
{
    /** Increase the nesting level by 1. */
    mutating func inc() { self.push(1) }

    /**
     Decrease the nesting level by 1.
     - remark: As with `pop()`, it is an error to attempt to decrement when there
     is currently no nesting.
     */
    mutating func dec() { self.pop() }

    /** Increment the nesting level. */
    postfix static func ++ (operand: inout Self) { operand.inc() }
}
