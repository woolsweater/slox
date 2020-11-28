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
            disassembleInstruction(self.chunk, offset: ip.address)
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
                    case .readGlobal:
                        let index = self.ip.advanceTakingInt()
                        try self.readVariable(forNameAt: index)
                    case .readGlobalLong:
                        let index = self.ip.advanceTakingThreeByteInt()
                        try self.readVariable(forNameAt: index)
                    case .setGlobal:
                        let index = self.ip.advanceTakingInt()
                        try self.setValue(forNameAt: index)
                    case .setGlobalLong:
                        let index = self.ip.advanceTakingThreeByteInt()
                        try self.setValue(forNameAt: index)
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
            catch let undefined as UndefinedVariable {
                self.reportRuntimeError("Undefined variable '%@'",
                                        undefined.renderedName)
                return .runtimeError
            }
            catch {
                return .runtimeError
            }
        }
    }

    private struct BinaryOperandError : Error {}
    private struct UndefinedVariable : Error
    {
        let name: StringRef
        var renderedName: String { String(cString: self.name.chars) }
    }

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
            self.reportRuntimeError("Operands must both be numbers.")
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
        guard let name = self.variableNameConstant(at: index) else {
            fatalError("Internal error: variable name lookup failed")
        }

        self.globals.insert(self.stack.peek(), for: name)
        // Wait to pop until the hash table has stored the value in
        // case the insert triggers garbage collection
        _ = self.stack.pop()
    }

    private func readVariable(forNameAt index: Int) throws
    {
        guard let name = self.variableNameConstant(at: index) else {
            fatalError("Internal error: variable name lookup failed")
        }

        guard let value = self.globals.value(for: name) else {
            throw UndefinedVariable(name: name)
        }

        self.stack.push(value)
    }

    private func setValue(forNameAt index: Int) throws
    {
        guard let name = self.variableNameConstant(at: index) else {
            fatalError("Internal error: variable name lookup failed")
        }

        let value = self.stack.peek()
        guard !self.globals.insert(value, for: name) else {
            // Clean up in case we're in a REPL context:
            // Back out the name so that it remains undefined
            self.globals.deleteValue(for: name)
            // The stack will be cleaned up in the error handler
            
            throw UndefinedVariable(name: name)
        }
    }

    private func variableNameConstant(at index: Int) -> StringRef?
    {
        let constant = self.chunk.constants[index]
        guard constant.isObject(kind: .string) else {
            assertionFailure("Cannot read variable name at constant offset \(index)")
            return nil
        }

        return constant.object!.asStringRef()
    }

    //MARK:- Error reporting

    private func reportRuntimeError(_ format: String, _ values: CVarArg...)
    {
        let message = String(format: format, arguments: values)
        let lineNumber = self.chunk.lineNumber(forByteAt: self.ip.address)
        StdErr.print("\(lineNumber): error: Runtime Error: \(message)")

        self.stack.reset()
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
        self.copyBytes(to: &int, count: byteCount)

        return Int(CFSwapInt32LittleToHost(int))
    }

    /**
     Copy the next `count` bytes from `code` into the given 4-byte space.
     - important: Do not attempt to copy more than 4 bytes.
     */
    private func copyBytes(to dest: inout UInt32, count: Int)
    {
        precondition(count <= (dest.bitWidth / 8))
        withUnsafeMutableBytes(of: &dest) { (bytes) in
            for i in 0..<count {
                bytes[i] = self.code[self.address + i]
            }
        }
    }
}
