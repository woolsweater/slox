import Foundation

/**
 Emit a human-readable representation of the given `Chunk`, with information
 about the opcodes and stored values.
 */
func disassemble(_ chunk: Chunk, name: String)
{
    print("== \(name) ==")

    var i = 0
    while i < chunk.code.count {
        i = disassembleInstruction(chunk, offset: i)
    }
}

/**
 Emit a human-readable representation of the instruction at `offset` in
 the given `Chunk`, then return the offset of the next instruction.
 */
func disassembleInstruction(_ chunk: Chunk, offset: Int) -> Int
{
    print(String(format:"%04d", offset), terminator: " ")

    let lineNumber = chunk.lineNumber(forByteAt: offset)
    if offset > 0 && lineNumber == chunk.lineNumber(forByteAt: offset - 1) {
        print("   |", terminator: " ")
    }
    else {
        print(String(format: "%04d", lineNumber), terminator: " ")
    }

    guard let instruction = OpCode(rawValue: chunk.code[offset]) else {
        print("Unknown opcode '\(chunk.code[offset])'")
        return offset + 1
    }

    switch instruction {
        case .constant, .constantLong:
            return constantInstruction(instruction, chunk, offset)
        default:
            return simpleInstruction(instruction, offset)
    }
}

private func simpleInstruction(_ code: OpCode, _ offset: Int) -> Int
{
    print(code.debugName)
    return offset + code.stepSize
}

private func constantInstruction(_ code: OpCode,
                                 _ chunk: Chunk,
                                 _ instructionOffset: Int)
    -> Int
{
    let isLong = (code == .constantLong)
    let idx = isLong ? calculateLongConstantIndex(chunk, instructionOffset + 1)
                     : Int(chunk.code[instructionOffset + 1])
    let paddedName = code.debugName.padding(toLength: 16, withPad: " ", startingAt: 0)
    print(String(format: "%@ %4d", paddedName, idx), terminator: " ")
    printValue(chunk.constants[idx])

    return instructionOffset + code.stepSize
}

private func calculateLongConstantIndex(_ chunk: Chunk, _ offset: Int) -> Int
{
    let byteCount = 3
    return chunk.code[offset..<offset+byteCount].withUnsafeBytes {
        var int: UInt32 = 0
        memcpy(&int, $0.baseAddress, byteCount)
        return Int(CFSwapInt32LittleToHost(int))
    }
}

private func printValue(_ value: Value)
{
    let description: String
    if case let .number(number) = value {
        description = String(format: "%g", number)
    }
    else if case let .bool(boolean) = value {
        description = "\(boolean)"
    }
    else {
        description = "nil"
    }

    print("'\(description)'")
}

private extension OpCode
{
    var debugName: String
    {
        switch self {
            case .return: return "OP_RETURN"
            case .constant: return "OP_CONSTANT"
            case .constantLong: return "OP_CONSTANT_LONG"
            case .nil: return "OP_NIL"
            case .true: return "OP_TRUE"
            case .false: return "OP_FALSE"
            case .not: return "OP_NOT"
            case .negate: return "OP_NEGATE"
            case .equal: return "OP_EQUAL"
            case .greater: return "OP_GREATER"
            case .less: return "OP_LESS"
            case .add: return "OP_ADD"
            case .subtract: return "OP_SUBTRACT"
            case .multiply: return "OP_MULTIPLY"
            case .divide: return "OP_DIVIDE"
        }
    }

    var stepSize: Int
    {
        switch self {
            case .constant: return 2
            case .constantLong: return 4
            default: return 1
        }
    }
}
