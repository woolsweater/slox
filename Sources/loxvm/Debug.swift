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
private func disassembleInstruction(_ chunk: Chunk, offset: Int) -> Int
{
    print(String(format:"%04d", offset), terminator: " ")

    let lineNumber = chunk.lineNumber(forByteAt: offset)
    if offset > 0 && lineNumber == chunk.lineNumber(forByteAt: offset - 1) {
        print("   |", terminator: " ")
    }
    else {
        print(String(format: "%04d", lineNumber), terminator: " ")
    }

    let instruction = chunk.code[offset]
    switch instruction {
        case OpCode.return.rawValue:
            return simpleInstruction("OP_RETURN", offset)
        case OpCode.constant.rawValue:
            return constantInstruction("OP_CONSTANT", chunk, offset)
        case OpCode.constantLong.rawValue:
            return constantInstruction("OP_CONSTANT_LONG", chunk, offset, isLong: true)
        default:
            print("Unknown opcode \(instruction)")
            return offset + 1
    }
}

private func simpleInstruction(_ name: String, _ offset: Int) -> Int
{
    print(name)
    return offset + 1
}

private func constantInstruction(_ name: String,
                                 _ chunk: Chunk,
                                 _ instructionOffset: Int,
                                 isLong: Bool = false)
    -> Int
{
    let idx = isLong ? calculateConstantIndex(chunk, instructionOffset + 1)
                     : Int(chunk.code[instructionOffset + 1])
    let paddedName = name.padding(toLength: 16, withPad: " ", startingAt: 0)
    print(String(format: "%@ %4d", paddedName, idx), terminator: " ")
    printValue(chunk.constants[idx])

    return instructionOffset + (isLong ? 4 : 2)
}

private func calculateConstantIndex(_ chunk: Chunk, _ offset: Int) -> Int
{
    return chunk.code[offset..<offset+3].reduce(into: 0, {
        (int, byte) in
        int <<= 8
        int |= Int(byte)
    })
}

private func printValue(_ value: Value)
{
    let description = String(format: "%g", value)
    print("'\(description)'")
}
