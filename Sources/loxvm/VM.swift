import Foundation

/** Interpreter of a series of bytecode instructions in a `Chunk`. */
class VM
{
    /**
     Allocation size of the stack; the maximum number of elements that can be stored.
     */
    private static let stackMaxSize = 256

    /** The bytecode currently being interpreted. */
    private(set) var chunk: Chunk!
    /** Index into the bytecode. */
    private var ip: InstructionPointer!
    /** Storage space for values derived from interpretation. */
    private var stack = RawStack<Value>(size: VM.stackMaxSize)
}

enum InterpretResult
{
    case okay
    case compileError
    case runtimeError
}

extension VM
{
    /** Interpret the given source code, reporting whether an error occurred. */
    func interpret(source: String) -> InterpretResult
    {
        let compiler = Compiler(source: source)
        guard let compiledChunk = compiler.compile() else {
            return .compileError
        }

        self.chunk = compiledChunk
        self.ip = InstructionPointer(code: self.chunk.code)

        return self.run()
    }

    private func run() -> InterpretResult
    {
        guard self.chunk?.code.isEmpty == false else { return .okay }

        while true {

            #if DEBUG_TRACE_EXECUTION
            print("        ")
            self.stack.printContents()
            _ = disassembleInstruction(self.chunk, offset: ip.address)
            #endif

            guard let opCode = self.ip.advanceTakingOpCode() else {
                fatalError("Unknown instruction: '\(ip.pointee)'")
            }

            do {
                switch opCode {
                    case .return:
                        print(self.stack.pop())
                        return .okay
                    case .constant:
                        let offset = self.ip.advanceTakingInt()
                        let constant = self.chunk.constants[offset]
                        self.stack.push(constant)
                    case .constantLong:
                        let offset = self.ip.advanceTakingThreeByteInt()
                        let constant = self.chunk.constants[offset]
                        self.stack.push(constant)
                    case .negate:
                        guard case let .number(value) = self.stack.peek() else {
                            self.reportRuntimeError("Operand must be a number.")
                            return .runtimeError
                        }
                        _ = self.stack.pop()
                        self.stack.push(.number(-value))
                    case .add:
                        try self.performBinaryOp(+)
                    case .subtract:
                        try self.performBinaryOp(-)
                    case .multiply:
                        try self.performBinaryOp(*)
                    case .divide:
                        try self.performBinaryOp(/)
                    default:
                        fatalError("Unhandled instruction: '\(opCode)'")
                }
            }
            catch {
                return .runtimeError
            }

        }
    }

    private struct BinaryOperandError : Error {}

    private func performBinaryOp(_ operation: (Double, Double) -> Double) throws
    {
        guard
            case let .number(right) = self.stack.peek(),
            case let .number(left) = self.stack.peek(distance: 1) else
        {
            self.reportRuntimeError("Operands must be numbers.")
            throw BinaryOperandError()
        }

        _ = self.stack.pop()
        _ = self.stack.pop()

        self.stack.push(.number(operation(left, right)))

    }

    //MARK:- Error reporting

    private func reportRuntimeError(_ format: String, _ values: CVarArg...)
    {
        let message = String(format: format, arguments: values)
        let lineNumber = self.chunk.lineNumber(forByteAt: self.ip.address)
        StdErr.print("\(lineNumber): error: Runtime Error: \(message)")
    }
}

/** Simulate a pointer to a raw byte buffer given a Swift `Array`. */
private struct InstructionPointer
{
    typealias Code = [UInt8]

    /** The current index into the bytes. */
    private(set) var address: Code.Index

    /** The byte array. */
    let code: Code

    /** The byte at the current index. */
    var pointee: UInt8 { return self.code[self.address] }

    /**
     Create a "pointer" into the given array.
     - warning: Traps if the array is empty.
     */
    init(code: Code)
    {
        self.address = code.indices.first!
        self.code = code
    }
}

private extension InstructionPointer
{
    static func += (lhs: inout InstructionPointer, rhs: Code.Index)
    {
        lhs.address += rhs
    }

    /**
     Try to form an `OpCode` value with the current `pointee`, moving the pointer ahead
     by one byte if successful.
     */
    mutating func advanceTakingOpCode() -> OpCode?
    {
        guard let code = OpCode(rawValue: self.pointee) else { return nil }
        self += 1
        return code
    }

    /** Construct an `Int` with the current `pointee` then move the pointer ahead one byte. */
    mutating func advanceTakingInt() -> Int
    {
        defer { self += 1 }
        return Int(self.pointee)
    }

    /**
     Construct an `Int` with the next three byte values, little-endian-wise, then step the pointer
     past those bytes.
     */
    mutating func advanceTakingThreeByteInt() -> Int
    {
        let byteCount = 3
        defer { self += byteCount }

        var int: UInt32 = 0
        memcpy(&int, self, byteCount)

        return Int(CFSwapInt32LittleToHost(int))
    }
}

/**
 Pretend that the given `UInt32` and `InstructionPointer` are raw memory and copy
 `count` bytes from the latter to the former.
 - important: Do not attempt to copy more than 4 bytes.
 */
private func memcpy(_ dest: inout UInt32, _ src: InstructionPointer, _ count: Int)
{
    precondition(count <= dest.bitWidth)
    withUnsafeMutableBytes(of: &dest) { (bytes) in
        for i in 0..<count {
            bytes[i] = src.code[src.address + i]
        }
    }
}
