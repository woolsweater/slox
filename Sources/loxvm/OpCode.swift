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
     Add a name to the current interpretation context's global variable
     table. The operand is the index into the `constants` table where the
     name is stored; the initial value is on the VM's stack.
     - remark: The "long" variant means that the index is stored across the
     next _three_ bytes, rather than one.
     */
    case defineGlobal, defineGlobalLong

    /** Built-in literal values */
    case `nil`, `true`, `false`

    /** Unary operators, with operands on the VM's stack. */
    case not, negate

    /** Comparison operators, with operands on the VM's stack. */
    case equal, greater, less

    /** Arithmetic operators, with operands on the VM's stack. */
    case add, subtract, multiply, divide

    /** The operation for an expression statement; it is evaluated and discarded. */
    case pop
}
