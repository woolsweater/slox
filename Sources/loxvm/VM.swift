import Foundation
import loxvm_object

/** Interpreter of a series of bytecode instructions in a `Chunk`. */
class VM
{
    /**
     Allocation size of the stack; the maximum number of elements that can be stored.
     */
    private static let stackMaxSize = 256

    /** Creator and tracker for heap allocations. */
    private let allocator: MemoryManager
    /** The bytecode currently being interpreted. */
    private(set) var chunk: Chunk!
    /** Index into the bytecode. */
    private var ip: InstructionPointer!
    /** Storage space for values derived from interpretation. */
    private var stack: RawStack<Value>
    /** All unique string values known to this interpretation context. */
    private var strings: HashTable
    /** Variables that have been defined at global scope in this interpretation context. */
    private var globals: HashTable

    init()
    {
        let allocator = MemoryManager()
        self.allocator = allocator
        self.stack = RawStack<Value>(size: VM.stackMaxSize, allocator: allocator)
        self.strings = HashTable(manager: allocator)
        self.globals = HashTable(manager: allocator)
    }

    deinit
    {
        self.stack.destroy(allocator: self.allocator)
    }
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
        let compiler = Compiler(source: source, stringsTable: self.strings, allocator: self.allocator)
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
                        return .okay
                    case .print:
                        print(self.stack.pop().formatted())
                    case .constant:
                        let index = self.ip.advanceTakingInt()
                        let constant = self.chunk.constants[index]
                        self.stack.push(constant)
                    case .constantLong:
                        let index = self.ip.advanceTakingThreeByteInt()
                        let constant = self.chunk.constants[index]
                        self.stack.push(constant)
                    case .defineGlobal:
                        let index = self.ip.advanceTakingInt()
                        self.defineVariable(forNameAt: index)
                    case .defineGlobalLong:
                        let index = self.ip.advanceTakingThreeByteInt()
                        self.defineVariable(forNameAt: index)
                    case .nil:
                        self.stack.push(.nil)
                    case .true:
                        self.stack.push(.bool(true))
                    case .false:
                        self.stack.push(.bool(false))
                    case .not:
                        let value = self.stack.pop()
                        self.stack.push(.bool(value.isFalsey))
                    case .negate:
                        guard case let .number(value) = self.stack.peek() else {
                            self.reportRuntimeError("Operand to '-' must be a number.")
                            return .runtimeError
                        }
                        _ = self.stack.pop()
                        self.stack.push(.number(-value))
                    case .equal:
                        let right = self.stack.pop()
                        let left = self.stack.pop()
                        self.stack.push(.bool(left == right))
                    case .less:
                        try self.performBinaryOp(<, wrapper: Value.bool)
                    case .greater:
                        try self.performBinaryOp(>, wrapper: Value.bool)
                    case .add:
                        if case .object(_) = self.stack.peek(), case .object(_) = self.stack.peek(distance: 1) {
                            try self.concatenate()
                        }
                        else {
                            try self.performBinaryOp(+, wrapper: Value.number)
                        }
                    case .subtract:
                        try self.performBinaryOp(-, wrapper: Value.number)
                    case .multiply:
                        try self.performBinaryOp(*, wrapper: Value.number)
                    case .divide:
                        try self.performBinaryOp(/, wrapper: Value.number)
                    case .pop:
                        _ = self.stack.pop()
                }
            }
            catch {
                return .runtimeError
            }
        }
    }

    private struct BinaryOperandError : Error {}

    private func concatenate() throws
    {
        guard
            self.stack.peek().isObject(kind: .string),
            self.stack.peek(distance: 1).isObject(kind: .string) else
        {
            self.reportRuntimeError("Operands must both be strings")
            throw BinaryOperandError()
        }

        let right = self.stack.pop().object!.asStringRef()
        let left = self.stack.pop().object!.asStringRef()

        let concatenated = self.allocator.createString(concatenating: left, right)

        let string: StringRef
        if let interned = self.strings.findString(matching: concatenated) {
            self.allocator.destroyObject(concatenated)
            string = interned
        }
        else {
            self.strings.insert(.nil, for: concatenated)
            string = concatenated
        }

        self.stack.push(.object(string.asBaseRef()))
    }

    private func performBinaryOp<T>(_ operation: (Double, Double) -> T, wrapper: (T) -> Value) throws
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

        self.stack.push(wrapper(operation(left, right)))
    }

    /**
     Get a variable name from the `Chunk`'s constants list at the given
     index, and insert it into the `globals` table with the value at the
     top of the stack.
     */
    private func defineVariable(forNameAt index: Int)
    {
        let value = self.chunk.constants[index]
        assert(value.isObject(kind: .string),
               "Cannot read variable name at constant offset \(index)")
        let name = value.object!.asStringRef()
        self.globals.insert(self.stack.peek(), for: name)
        // Wait to pop until the hash table has stored the value in
        // case the insert triggers garbage collection
        _ = self.stack.pop()
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
    precondition(count <= (dest.bitWidth / 8))
    withUnsafeMutableBytes(of: &dest) { (bytes) in
        for i in 0..<count {
            bytes[i] = src.code[src.address + i]
        }
    }
}
