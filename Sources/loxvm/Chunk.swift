import Foundation

/** A sequence of bytecode with auxiliary information. */
struct Chunk
{
    /** The bytecode itself: opcodes plus their operands. */
    private(set) var code: [UInt8] = []

    /**
     Storage for constant values used in this chunk.
     - remark: The chunk takes advantage of the fact that strings
     (including variable names) are deduplicated and does not
     insert one that already exists in the list.
     */
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
     Add the given constant value, which corresponds to an item at `line` in
     the original source, to the `Chunk`'s storage. Then write the appropriate
     `OpCode` (using the long variant of the code that was passed, if needed) and
     the index to the bytecode.
     - returns: `false` if there are too many constants already present in the chunk.
     */
    mutating func write(constant: Value, operation: OpCode, line: Int) -> Bool
    {
        let index = self.add(constant: constant)
        guard index <= Int.threeByteMax else { return false }

        if index <= UInt8.max {
            self.write(opCode: operation, line: line)
            self.write(byte: UInt8(index), line: line)
        }
        else {
            self.write(opCode: operation.longVariant, line: line)
            self.write(triple: index, line: line)
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
     - remark: Since strings (including variable names) are uniqued by
     the `Compiler`, if the new value is a string and can be found in
     the constants list already, it is not added again and the existing
     index is returned.
     */
    private mutating func add(constant: Value) -> Int
    {
        if constant.isObject(kind: .string), let index = self.constants.firstIndex(of: constant) {
            return index
        } else {
            self.constants.append(constant)
            return self.constants.endIndex - 1
        }
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

private extension OpCode
{
    var longVariant: OpCode
    {
        switch self {
            case .constant: return .constantLong
            case .defineGlobal: return .defineGlobalLong
            case .readGlobal: return .readGlobalLong
            case .setGlobal: return .setGlobalLong
            default:
                fatalError("\(self) has no long variant")
        }
    }
}
