import Foundation

/** A single instruction for the VM. */
enum OpCode : UInt8
{
    case `return`
    case constant, constantLong
    case `nil`, `true`, `false`
    case not
    case negate
    case equal, greater, less
    case add, subtract, multiply, divide
}

/** A sequence of bytecode with auxiliary information. */
struct Chunk
{
    /** The bytecode itself: opcodes plus their operands. */
    private(set) var code: [UInt8] = []

    /** Storage for constant values used in this chunk. */
    private(set) var constants: [Value] = []

    /**
     The lines in the original source code corresponding to each item
     in `code`. Run-length encoded. Used for debugging.
     */
    private var lineNumbers: [(Int, count: Int)] = []
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
        if line == self.lineNumbers.last?.0 {
            self.lineNumbers.mutateLast { $0.count += 1 }
        }
        else {
            self.lineNumbers.append((line, count: 1))
        }
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
     Add the given constant value, which corresponds to an item at `line`
     in the original source, to the `Chunk`'s storage.
     - returns: `false` if there are too many constants already present in the chunk.
     */
    mutating func write(constant: Value, line: Int) -> Bool
    {
        let idx = self.add(constant: constant)

        if idx <= UInt8.max {
            self.write(opCode: .constant, line: line)
            self.write(byte: UInt8(idx), line: line)
            return true
        }
        else if idx <= Int.threeByteMax {
            self.write(opCode: .constantLong, line: line)
            self.write(triple: idx, line: line)
            return true
        }
        else {
            return false
        }
    }

    private mutating func write(triple: Int, line: Int)
    {
        precondition(triple <= Int.threeByteMax, "Input too large: \(triple)")

        var triple = triple.littleEndian
        withUnsafeBytes(of: &triple) { (buf) in
            self.write(byte: buf[0], line: line)
            self.write(byte: buf[1], line: line)
            self.write(byte: buf[2], line: line)
        }
    }

    /**
     Add the given constant value to the `Chunk`'s storage. The index
     where it is stored is returned.
     */
    private mutating func add(constant: Value) -> Int
    {
        self.constants.append(constant)
        return self.constants.count - 1
    }
}

//MARK:- Line numbers

extension Chunk
{
    /**
     Produce the line number in the original source code for the item found
     at `offset` in the chunk's `code`.
     */
    func lineNumber(forByteAt offset: Int) -> Int
    {
        var runningCount = 0
        let record = self.lineNumbers.first(where: { (record) in
            defer { runningCount += record.count }
            return runningCount + record.count > offset
        })

        return record!.0
    }
}

private extension Array
{
    /**
     Directly change the value of the last element using the given function.
     - warning: Traps if the array is empty.
     */
    mutating func mutateLast(_ mutate: (inout Element) -> Void)
    {
        precondition(!(self.isEmpty))
        let lastIndex = self.indices.last!
        mutate(&self[lastIndex])
    }
}

private extension Int
{
    /** The highest value that can be stored in three bytes unsigned. */
    static let threeByteMax = 16777215
}
