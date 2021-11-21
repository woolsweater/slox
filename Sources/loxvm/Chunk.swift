import Foundation

/** A sequence of bytecode with auxiliary information. */
struct Chunk
{
    /** The bytecode itself: opcodes plus their operands. */
    private(set) var code: [UInt8] = []

    /** Storage for constant values used in this chunk. */
    private(set) var constants: [Value] = []    //TODO: This should be managed by Lox

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
            self.lineNumbers.mutateLast({ $0.count += 1 })
        }
        else {
            self.lineNumbers.append((line, count: 1))
        }
    }

    /**
     Replace the three bytes starting at `index` in `code` with the
     bytes of `triple`, read little-endian-wise.
     - precondition: `triple`'s value must fit into three bytes.
     */
    mutating func overwriteBytes(at index: Int, with triple: Int)
    {
        precondition(triple <= Int.threeByteMax, "Input too large: \(triple)")

        var triple = triple.littleEndian
        withUnsafeBytes(of: &triple, { (buf) in
            self.code[index] = buf[0]
            self.code[index+1] = buf[1]
            self.code[index+2] = buf[2]
        })
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
     Add the given constant value, which corresponds to an item at `line` in the
     original source, to the `Chunk`'s storage. Then write the appropriate
     `OpCode` (using the long variant of the code that was passed, if needed)
     and the index to the bytecode.
     - returns: `false` if there are too many constants already present in the
     chunk, else `true`.
     */
    mutating func write(constant: Value, operation: OpCode, line: Int) -> Bool
    {
        let index = self.add(constant: constant)
        guard index <= Int.threeByteMax else { return false }

        self.write(operation: operation, argument: index, line: line)

        return true
    }

    /**
     Add an `operation` to the bytecode, along with the `argument` that it
     should use. The long variant of `operation` is written if needed.

     - remark: The target collection of the `argument` varies according to the
     `operation` itself; in some cases it is the chunk's `constants` table, but
     it may not be.
     */
    mutating func write(operation: OpCode, argument: Int, line: Int)
    {
        if argument <= UInt8.max {
            self.write(opCode: operation, line: line)
            self.write(byte: UInt8(argument), line: line)
        }
        else {
            self.write(opCode: operation.longVariant, line: line)
            self.write(triple: argument, line: line)
        }
    }

    private mutating func write(triple: Int, line: Int)
    {
        precondition(triple <= Int.threeByteMax, "Input too large: \(triple)")

        var triple = triple.littleEndian
        withUnsafeBytes(of: &triple, { (buf) in
            self.write(byte: buf[0], line: line)
            self.write(byte: buf[1], line: line)
            self.write(byte: buf[2], line: line)
        })
    }

    /**
     Add the given constant value to the `Chunk`'s storage. The index
     where it is stored is returned.
     */
    private mutating func add(constant: Value) -> Int
    {
        self.constants.append(constant)
        return self.constants.endIndex - 1
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

private extension Int
{
    /** The highest value that can be stored in three bytes unsigned. */
    static let threeByteMax = 0xff_ffff
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
            case .jump: return .jumpLong
            default:
                fatalError("\(self) has no long variant")
        }
    }
}
