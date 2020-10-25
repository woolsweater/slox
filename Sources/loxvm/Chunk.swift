import Foundation

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
     Add the given `Value`, a string that is the name of a global variable
     declared at the given line number, to the `Chunk`'s storage.
     - returns: `false` if there are too many constants already present in the chunk.
     */
    mutating func write(globalName: Value, line: Int) -> Bool
    {
        assert(globalName.isObject(kind: .string), "Global variable name must be a string")
        return self.write(constant: globalName, isGlobal: true, line: line)
    }

    /**
     Add the given constant value, which corresponds to an item at `line`
     in the original source, to the `Chunk`'s storage.
     - returns: `false` if there are too many constants already present in the chunk.
     */
    mutating func write(constant: Value, line: Int) -> Bool
    {
        return self.write(constant: constant, isGlobal: false, line: line)
    }

    private mutating func write(constant: Value, isGlobal: Bool, line: Int) -> Bool
    {
        let idx = self.add(constant: constant)
        guard idx <= Int.threeByteMax else { return false }

        if idx <= UInt8.max {
            let opCode: OpCode = isGlobal ? .defineGlobal : .constant
            self.write(opCode: opCode, line: line)
            self.write(byte: UInt8(idx), line: line)
        }
        else {
            let opCode: OpCode = isGlobal ? .defineGlobalLong : .constantLong
            self.write(opCode: opCode, line: line)
            self.write(triple: idx, line: line)
        }

        return true
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
