import Foundation

/** Tracks levels of nesting of some language construct, e.g. loops. */
struct NestingCounter
{
    /**
     The current nesting level.
     - remark: This can never be less than zero; trying to decrement it
     when it is already zero is a programming error.
     */
    private(set) var level: Int = 0

    /** Whether there currently is a non-zero level of nesting.  */
    var isNested: Bool { return self.level > 0 }

    /** Increment the nesting level. */
    mutating func inc()
    {
        self.level += 1
    }

    /**
     Decrement the nesting level.
     - remark: It is an error to attempt to decrement when the level is 0
     */
    mutating func dec()
    {
        guard self.level > 0 else { fatalError("Not in a nested context") }
        self.level -= 1
    }
}

postfix operator ++
postfix operator --

extension NestingCounter
{
    /** Increment the nesting level. */
    postfix static func ++ (operand: inout NestingCounter) { operand.inc() }

    /**
     Decrement the nesting level.
     - remark: It is an error to attempt to decrement when the level is 0
     */
    postfix static func -- (operand: inout NestingCounter) { operand.dec() }
}
