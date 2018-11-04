import Foundation

/** A single instruction for the VM. */
enum OpCode : UInt8
{
    case `return`, constant
}

/** A sequence of bytecode with auxiliary information. */
struct Chunk
{
    /** The bytecode itself: opcodes plus their operands. */
    private(set) var code: [UInt8] = []

    /** Storage for constant values used in this chunk. */
    private(set) var constants: [Value] = []

    /**
     The line in the original source code corresponding to each item
     in `code`. Used for debugging.
     */
    private(set) var lineNumbers: [Int] = []
}

extension Chunk
{
    /**
     Add the given byte, which represents an item at `line` in the
     original source, to the `Chunk`'s `code` list.
     */
    mutating func write(byte: UInt8, line: Int)
    {
        self.code.append(byte)
        self.lineNumbers.append(line)
    }

    /**
     Add the given opcode, which represents an item at `line` in the
     original source, to the `Chunk`'s `code` list.
     */
    mutating func write(opCode: OpCode, line: Int)
    {
        self.write(byte: opCode.rawValue, line: line)
    }

    /**
     Add the given constant value to the `Chunk`'s storage. The index
     where it is stored is returned.
     */
    mutating func add(constant: Value) -> UInt8
    {
        self.constants.append(constant)
        return UInt8(self.constants.count - 1)
    }
}
