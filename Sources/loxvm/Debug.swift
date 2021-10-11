import Foundation
import loxvm_object

/**
 Emit a human-readable representation of the instruction at `offset` in the
 given `Chunk`, looking up values as needed in `globals`, `chunk.constants`, and
 `stack`.
 */
func disassembleInstruction(at offset: Int, in chunk: Chunk, globals: GlobalVariables, stack: RawStack<Value>)
{
    print(String(format:"%04d", offset), terminator: " ")

    let lineNumber = chunk.lineNumber(forByteAt: offset)
    if offset > 0 && lineNumber == chunk.lineNumber(forByteAt: offset - 1) {
        // Continuation of a source line
        print("|    ", terminator: " ")
    }
    else {
        // New source line
        print(String(format: "L%04d", lineNumber), terminator: " ")
    }

    guard let instruction = OpCode(rawValue: chunk.code[offset]) else {
        print("Unknown opcode '\(chunk.code[offset])'")
        return
    }

    if let argument = argument(for: instruction, at: offset, in: chunk.code) {
        printArgumentInstruction(
            instruction,
            argument,
            constants: chunk.constants,
            globals: globals,
            stack: stack
        )
    }
    else {
        print(instruction.debugName)
    }
}

/**
 Render the name, raw argument (a storage index), and actual operand value for
 `opCode`, which must be an instruction that takes an argument.
 - remark: The interpretation of the argument index and value depend on the
 particular instruction -- the storage location may be `constants`, `globals`,
 or the `stack`. For reads the arugment is the value currently stored; for
 writes/definitions it is the new incoming value
 */
private func printArgumentInstruction(
    _ opCode: OpCode,
    _ argument: Int,
    constants: [Value],
    globals: GlobalVariables,
    stack: RawStack<Value>
)
{
    let paddedName = opCode.debugName.padding(toLength: 16, withPad: " ", startingAt: 0)
    print(String(format: "%@ %4d", paddedName, argument), terminator: " ")

    let argumentValue: Value?
    switch opCode {
        case .constant, .constantLong:
            argumentValue = constants[argument]
        case .readGlobal, .readGlobalLong:
            argumentValue = try? globals.readValue(at: argument)
        case .setGlobal, .setGlobalLong,
             .defineGlobal, .defineGlobalLong:
            argumentValue = stack.peek()
        case .readLocal:
            argumentValue = stack[localSlot: argument]
        case .setLocal:
            argumentValue = stack.peek()
        default:
            fatalError("Internal error: Not an argument instruction: \(opCode)")
    }

    let argumentDescription = argumentValue?.formatted() ?? "«uninitialized»"
    print(argumentDescription)
}

/**
 If `opCode` is one that takes an argument, look at the following bytes and
 return the argument index that they form. If `opCode` does not take an
 argument, return `nil`.
 */
private func argument(for opCode: OpCode, at operandOffset: Int, in byteCode: [UInt8]) -> Int?
{
    let argumentOffset = operandOffset + 1
    switch opCode {
        case .constant, .defineGlobal,
             .readGlobal, .setGlobal,
             .readLocal, .setLocal:
            return Int(byteCode[argumentOffset])
        case .constantLong, .defineGlobalLong, .readGlobalLong, .setGlobalLong:
            let argumentEnd = argumentOffset + 3
            return byteCode[argumentOffset..<argumentEnd].loadInt()
        case .return, .print, .nil, .true, .false, .not, .negate, .equal,
             .greater, .less, .add, .subtract, .multiply,
             .divide, .pop:
            return nil
    }
}

private extension OpCode
{
    /** Human-readable string for this instruction. */
    var debugName: String
    {
        switch self {
            case .return: return "OP_RETURN"
            case .print: return "OP_PRINT"
            case .constant: return "OP_CONSTANT"
            case .constantLong: return "OP_CONSTANT_LONG"
            case .defineGlobal: return "OP_DEFINE_GLOBAL"
            case .defineGlobalLong: return "OP_DEFINE_GLOBAL_LONG"
            case .readGlobal: return "OP_READ_GLOBAL"
            case .readGlobalLong: return "OP_READ_GLOBAL_LONG"
            case .setGlobal: return "OP_SET_GLOBAL"
            case .setGlobalLong: return "OP_SET_GLOBAL_LONG"
            case .readLocal: return "OP_READ_LOCAL"
            case .setLocal: return "OP_SET_LOCAL"
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
}

private extension ArraySlice where Element == UInt8
{
    /**
     Take the next `count` bytes as the raw contents of a little-endian integer
     and return that value.
     */
    func loadInt() -> Int
    {
        precondition(1...4 ~= self.count)
        return self.withUnsafeBytes {
            var int: UInt32 = 0
            memcpy(&int, $0.baseAddress, self.count)
            return Int(CFSwapInt32LittleToHost(int))
        }
    }
}
