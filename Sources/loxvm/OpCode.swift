import Foundation

/** A single instruction for the VM. */
enum OpCode : UInt8
{
    /** Fundamental "command" statements */
    case `return`, print

    /**
     Read a value from the `Chunk`'s `constants` list; the operand is the
     index into that list.
     - remark: The "long" variant means that the index is stored across the
     next _three_ bytes, rather than one.
     */
    case constant, constantLong

    /**
     Initialize a global storage slot in the current interpretation context. The
     operand is the index where the value is to be stored; the initial value is
     on the VM's stack.
     - remark: The "long" variant means that the index is stored across the next
     _three_ bytes, rather than one.
     */
    case defineGlobal, defineGlobalLong

    /**
     Read a value from the current interpretation context's global variable
     table. The operand is the index where the value is stored.
     - remark: The "long" variant means that the index is stored across the
     next _three_ bytes, rather than one.
     */
    case readGlobal, readGlobalLong

    /**
     Bind a new value to an existing global storage slot in the current
     interpretation context. The operand is the index where the value is to be
     stored; the new value is on the VM's stack.
     - remark: The "long" variant means that the index is stored across the
     next _three_ bytes, rather than one.
     */
    case setGlobal, setGlobalLong

    /**
     Read a local variable from its position on the stack. The operand is the
     index where the value is stored.
     */
    case readLocal

    /**
     Bind a new value to an existing local storage slot on the stack. The
     operand is the index where the value is to be stored; the new value is at
     the top of the stack.
     */
    case setLocal

    /**
     Read the top value of the stack and move the instruction pointer if it is
     true or false respectively. The operand, which is stored across the next
     three bytes, is the index to jump to in the bytecode.
     - remark: The stack value is left in place, not popped.
     */
    case jumpIfTrue, jumpIfFalse

    /**
     Move the instruction pointer unconditionally. The operand, which is stored
     across the next three bytes, is the index to jump to in the bytecode.
     - remark: The "long" variant means that the index is stored across the next
     _three_ bytes, rather than one.
     */
    case jump, jumpLong

    /** Built-in literal values */
    case `nil`, `true`, `false`

    /** Unary operators, with operands on the VM's stack. */
    case not, negate

    /** Comparison operators, with operands on the VM's stack. */
    case equal, greater, less

    /**
     Like `equal`, but leaves the LHS on the stack when the comparison fails.
     */
    case match

    /** Arithmetic operators, with operands on the VM's stack. */
    case add, subtract, multiply, divide

    /**
     The operation for an expression statement; it is evaluated and discarded.
     */
    case pop
}

extension OpCode
{
    /** Byte size of a "long" instruction's operand */
    static let longOperandSize = 3
}
