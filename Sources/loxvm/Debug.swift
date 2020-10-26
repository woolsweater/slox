import Foundation
import loxvm_object

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
@discardableResult
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

    if instruction.hasOperand {
        return printOperandInstruction(instruction, at: offset, in: chunk)
    }
    else {
        return printSimpleInstruction(instruction, at: offset)
    }
}

private func printSimpleInstruction(_ opCode: OpCode, at offset: Int) -> Int
{
    print(opCode.debugName)
    return offset + opCode.byteSize
}

private func printOperandInstruction(_ opCode: OpCode,
                                     at instructionOffset: Int,
                                     in chunk: Chunk)
    -> Int
{
    let index = calculateConstantIndex(for: opCode,
                                startingAt: instructionOffset + 1,
                                        in: chunk.code)
    let paddedName = opCode.debugName.padding(toLength: 16, withPad: " ", startingAt: 0)
    print(String(format: "%@ %4d", paddedName, index), terminator: " ")
    print("'\(chunk.constants[index].formatted())'")

    return instructionOffset + opCode.byteSize
}

private func calculateConstantIndex(for opCode: OpCode,
                                    startingAt operandOffset: Int,
                                    in byteCode: [UInt8])
    -> Int
{
    let operandSize = opCode.byteSize - 1
    if operandSize == 1 {
        return Int(byteCode[operandOffset])
    }
    else {
        assert(2...4 ~= operandSize)
        return byteCode[operandOffset..<(operandOffset+operandSize)].withUnsafeBytes {
            var int: UInt32 = 0
            memcpy(&int, $0.baseAddress, operandSize)
            return Int(CFSwapInt32LittleToHost(int))
        }
    }
}

private extension OpCode
{
    var debugName: String
    {
        switch self {
            case .return: return "OP_RETURN"
            case .print: return "OP_PRINT"
            case .constant: return "OP_CONSTANT"
            case .constantLong: return "OP_CONSTANT_LONG"
            case .defineGlobal: return "OP_DEFINE_GLOBAL"
            case .defineGlobalLong: return "OP_DEFINE_GLOBAL_LONG"
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
            case .pop: return "OP_POP"
        }
    }

    /**
     The number of bytes the `OpCode` and its operand (if any) occupy.
     */
    var byteSize: Int
    {
        switch self {
            case .constant, .defineGlobal: return 2
            case .constantLong, .defineGlobalLong: return 4
            default: return 1
        }
    }

    var hasOperand: Bool { self.byteSize > 1 }
}
