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

        return self.run()
    }

    private func run() -> InterpretResult
    {
        guard self.chunk?.code.isEmpty == false else { return .okay }

        return self.chunk.code.withUnsafeBufferPointer { (bytes) -> InterpretResult in
            var ip = bytes.baseAddress!
            repeat {
                #if DEBUG_TRACE_EXECUTION
                print("        ")
                self.stack.printContents()
                _ = disassembleInstruction(self.chunk, offset: ip - bytes.baseAddress!)
                #endif
                guard let opCode = ip.advanceTakingOpCode() else {
                    fatalError("Unknown instruction: '\(ip.pointee)'")
                }
                switch opCode {
                    case .return:
                        print(self.stack.pop())
                        return .okay
                    case .constant:
                        let offset = ip.advanceTakingInt()
                        let constant = self.chunk.constants[offset]
                        self.stack.push(constant)
                    case .constantLong:
                        let offset = ip.advanceTakingThreeByteInt()
                        let constant = self.chunk.constants[offset]
                        self.stack.push(constant)
                    case .negate:
                        let value = self.stack.pop()
                        self.stack.push(-value)
                    case .add:
                        self.performBinaryOp(+)
                    case .subtract:
                        self.performBinaryOp(-)
                    case .multiply:
                        self.performBinaryOp(*)
                    case .divide:
                        self.performBinaryOp(/)
                    default:
                        fatalError("Unhandled instruction: '\(opCode)'")
                }
            } while true
        }
    }

    private func performBinaryOp(_ operation: (Value, Value) -> Value)
    {
        let rhs = self.stack.pop()
        let lhs = self.stack.pop()
        self.stack.push(operation(lhs, rhs))
    }
}

private extension UnsafePointer where Pointee == UInt8
{
    mutating func advanceTakingOpCode() -> OpCode?
    {
        guard let code = OpCode(rawValue: self.pointee) else { return nil }
        self += 1
        return code
    }

    mutating func advanceTakingInt() -> Int
    {
        defer { self += 1 }
        return Int(self.pointee)
    }

    mutating func advanceTakingThreeByteInt() -> Int
    {
        let byteCount = 3
        defer { self += byteCount }

        var int: Int = 0
        memcpy(&int, self, byteCount)

        return int
    }
}
