import Foundation
import loxvm_object

/**
 Translator from a token stream to bytecode stored in a `Chunk`, using a
 `Scanner` as a helper to get tokens from the provided source.
 */
class Compiler
{
    private enum Limit { static let localCount = Int(UInt8.max) }

    /** Description of current parsing with regard to error tokens and reporting. */
    fileprivate enum State
    {
        /** Compilation is proceeding without error. */
        case normal
        /**
         Compilation is continuing but an error was previously encountered. We will report as
         many further errors as possible, but discard generated bytecode without executing it.
         */
        case error
        /**
         We've just encountered an error and parsing is in an indeterminate state; error
         messages will be suppressed until we reach a synchronization point.
         */
        case panic
    }
    private var state: State = .normal

    private let scanner: Scanner
    private let strings: HashTable
    private let globals: GlobalVariables
    private var locals: LocalVariables
    private var currentScope: Scope = .global
    private let allocator: MemoryManager
    private lazy var stringCompiler = StringCompiler(allocate: { [allocator] in allocator.allocateBuffer(of: UInt8.self, count: $0) },
                                                      destroy: { [allocator] in allocator.destroyBuffer($0) })
    private var currentToken: Token = .dummy
    private var previousToken: Token = .dummy

    private var chunk: Chunk = Chunk()

    /**
     Create a compiler to operate on the given source, obtaining any neccessary
     heap memory from the provided allocator.
     */
    init(source: String,
         stringsTable: HashTable,
         globals: GlobalVariables,
         allocator: MemoryManager)
    {
        self.scanner = Scanner(source: source)
        self.strings = stringsTable
        self.globals = globals
        self.locals = LocalVariables(capacity: Limit.localCount)
        self.allocator = allocator
    }
}

extension Compiler
{
    /** Translate the source into bytecode. */
    func compile() -> Chunk?
    {
        self.advance()

        while !self.match(.EOF) {
            self.declaration()
        }

        guard self.state == .normal else {
            return nil
        }

        self.end()

        return self.chunk
    }

    private func end()
    {
        self.emitReturn()
    }

    /**
     Store the current token, then move past any error tokens, reporting them as appropriate.
     */
    private func advance()
    {
        self.previousToken = self.currentToken

        self.currentToken = self.scanner.scanToken()
        while self.currentToken.kind == .error {
            self.reportErrorAtCurrent(message: self.currentToken.lexeme)
            self.currentToken = self.scanner.scanToken()
        }
    }

    /**
     Check for a particular token kind at the current position, reporting an error if it is not
     found.
     */
    private func mustConsume(_ kind: Token.Kind, message: String)
    {
        guard self.currentToken.kind == kind else {
            self.reportErrorAtCurrent(message: message)
            return
        }

        self.advance()
    }

    private func match(_ kind: Token.Kind) -> Bool
    {
        guard self.check(kind) else { return false }
        self.advance()
        return true
    }

    private func check(_ kind: Token.Kind) -> Bool
    {
        self.currentToken.kind == kind
    }

    private func endOfBlockOrFile() -> Bool
    {
        self.check(.rightBrace) || self.check(.EOF)
    }

    //MARK:- Parsing

    private func expression()
    {
        self.parse(fromPrecedence: .joined)
    }

    private func declaration()
    {
        if self.match(.var) {
            self.variableDeclaration()
        }
        else {
            self.statement()
        }

        if self.state == .panic {
            self.synchronize()
        }
    }

    private func statement()
    {
        if self.match(.print) {
            self.printStatement()
        }
        else if self.match(.leftBrace) {
            self.inScope(self.block)
        }
        else if self.match(.if) || self.match(.unless) {
            self.ifStatement(inverted: self.previousToken.kind == .unless)
        }
        else if self.match(.for) {
            self.inScope(self.forStatement)
        }
        else if self.match(.match) {
            self.matchStatement()
        }
        else if self.match(.while) || self.match(.until) {
            self.whileStatement(inverted: self.previousToken.kind == .until)
        }
        else {
            self.expressionStatement()
        }
    }

    private func printStatement()
    {
        self.expression()
        self.mustConsume(.semicolon, message: "Expected ';' to terminate 'print' statement")
        self.emitBytes(for: .print)
    }

    private func block()
    {
        while !self.endOfBlockOrFile() {
            self.declaration()
        }

        self.mustConsume(.rightBrace, message: "Expected '}' to terminate block")
    }

    //MARK:- Control flow statements

    private func ifStatement(inverted: Bool)
    {
        //      ┌─────────────────────────┐
        //      │ Expression (peek stack) │
        //      └─┬───────────────────────┘
        //      ┌─▼───┐
        // False┤ JiF │  (reversed for 'unless')
        //    │ └─┬───┘
        //    │   │ True
        //    │  ┌▼────┐
        //    │  │ POP │
        //    │  └─┬───┘
        //    │  ┌─▼───────────┐
        //    │  │ "Then" body │
        //    │  └┬────────────┘
        //    │  ┌▼────┐
        //    │  │ JMP ├─────────┐
        //    │  └─────┘         │
        //    │  ┌─────┐         │
        //    └──▶ POP │         │
        //       └─┬───┘         │
        //       ┌─▼───────────┐ │
        //       │ "Else" body │ │
        //       └┬────────────┘ │
        //       ┌▼───────────┐  │
        //       │ (continue) ◀──┘
        //       └────────────┘

        self.mustConsume(.leftParen, message: "Expected '(' for '\(inverted ? "unless" : "if")' condition")
        self.expression()
        self.mustConsume(.rightParen, message: "Expected ')' for '\(inverted ? "unless" : "if")' condition")

        let thenBranch = self.emitJump(inverted ? .jumpIfTrue : .jumpIfFalse)
        self.emitBytes(for: .pop)

        self.statement()
        let thenBodyEnd = self.emitJump(.jump)

        self.emitBytes(for: .pop)
        self.patchJump(at: thenBranch)

        if self.match(.else) {
            guard !(inverted) else {
                return self.reportError(message: "'unless' statement cannot have an 'else' clause.")
            }
            self.statement()
        }

        self.patchJump(at: thenBodyEnd)
    }

    private func forStatement()
    {
        //         ┌─────────────┐
        //         │ Initializer │
        //         └─┬───────────┘
        //         ┌─▼───────────┐
        //         │  Condition  ◀───┐
        //         └─┬───────────┘   │
        //         ┌─▼───┐           │
        // False ──┤ JiF │           │
        //   │     └─┬───┘           │
        //   │     ┌─▼──┐            │
        //   │     │POP │            │
        //   │     └┬───┘            │
        //   │     ┌▼───┐            │
        //   │     │JUMP├─────────┐  │
        //   │     └────┘         │  │
        //   │                    │  │
        //   │     ┌───────────┐  │  │
        //   │  ┌──▶ Increment │  │  │
        //   │  │  └┬──────────┘  │  │
        //   │  │  ┌▼───┐         │  │
        //   │  │  │POP │         │  │
        //   │  │  └┬───┘         │  │
        //   │  │  ┌▼───┐        ┌┼┐ │
        //   │  │  │JUMP├────────┘│└─┘
        //   │  │  └────┘         │
        //   │  │                 │
        //   │  │  ┌───────────┐  │
        //   │  │  │   Body    ◀──┘
        //   │  │  └─┬─────────┘
        //   │  │   ┌▼───┐
        //   │  │   │JUMP│
        //   │  │   └─┬──┘
        //   │  └─────┘
        //   │
        //   │    ┌─────┐
        //   └────▶ POP │
        //        └─┬───┘
        //        ┌─▼────────┐
        //        │(continue)│
        //        └──────────┘

        self.mustConsume(.leftParen, message: "Expected '(' to begin 'for' statement clauses")
        self.forStatementInitializer()
        let conditionLoop = self.currentLoopLocation()
        let exitJump = self.forStatementCondition()
        let incrementLoop = self.forStatementIncrement(with: conditionLoop)

        self.statement()
        let loopStart = incrementLoop ?? conditionLoop
        self.emitLoop(backTo: loopStart)

        if let jump = exitJump {
            self.patchJump(at: jump)
            self.emitBytes(for: .pop)
        }
    }

    private func forStatementInitializer()
    {
        if self.match(.semicolon) {
            return
        }
        else if self.match(.var) {
            self.variableDeclaration()
        }
        else {
            self.expressionStatement()
        }
    }

    private func forStatementCondition() -> Int?
    {
        if self.match(.semicolon) {
            return nil
        }

        self.expression()
        self.mustConsume(.semicolon, message: "Expected ';' to terminate 'for' condition")
        let jump = self.emitJump(.jumpIfFalse)
        self.emitBytes(for: .pop)
        return jump
    }

    private func forStatementIncrement(with condition: LoopLocation) -> LoopLocation?
    {
        if self.match(.rightParen) {
            return nil
        }

        let bodyJump = self.emitJump(.jump)

        let incrementLoop = self.currentLoopLocation()
        self.expression()
        self.emitBytes(for: .pop)
        self.mustConsume(.rightParen, message: "Expected ')' to terminate 'for' clauses")

        self.emitLoop(backTo: condition)
        self.patchJump(at: bodyJump)

        return incrementLoop
    }

    private func matchStatement()
    {
        self.mustConsume(.leftParen, message: "Expected '(' to begin 'match' value")
        self.expression()
        self.mustConsume(.rightParen, message: "Expected ')' to terminate 'match' value")
        self.mustConsume(.leftBrace, message: "Expected '{' to begin 'match' body")

        // Although this is not actually a loop, as an implementation detail
        // breaking from every individual pattern arm will funnel back here, so
        // there is a single jump point to the end.

        //TODO: The jump to body should really be a short jump since we know it
        // only has one other instruction to pass over.
        let bodyJump = self.emitJump(.jump)
        let sharedExit = self.currentLoopLocation()
        let exitJump = self.emitJump(.jump)
        self.patchJump(at: bodyJump)

        var hasPattern = false
        while !self.endOfBlockOrFile() {
            if self.currentToken.isWildcard {
                hasPattern = true
                self.advance()
                self.matchWildcard()
            }
            else {
                hasPattern = true
                let patternLine = self.currentToken.lineNumber
                self.expression()
                self.matchArm(line: patternLine, exit: sharedExit)
            }
        }

        self.mustConsume(.rightBrace, message: "Expected '}' to terminate 'match' body")
        guard hasPattern else {
            self.reportError(message: "'match' statement must have at least one pattern")
            return
        }

        self.patchJump(at: exitJump)
    }

    private func matchArm(line: Int, exit: LoopLocation)
    {
        self.mustConsume(.arrow, message: "Expected '->' after pattern")
        self.emitBytes(for: .match, line: line)
        let matchFailJump = self.emitJump(.jumpIfFalse)
        self.emitBytes(for: .pop, line: line)
        self.statement()
        self.emitLoop(backTo: exit)
        self.patchJump(at: matchFailJump)
        self.emitBytes(for: .pop, line: line)

        // "Fall" into the next pattern clause (or just out of the statement)
    }

    private func matchWildcard()
    {
        self.emitBytes(for: .pop)
        self.mustConsume(.arrow, message: "Expected '->' after wildcard pattern")
        self.statement()
        if self.currentToken.isWildcard {
            //TODO: This should probably just be a warning
            self.reportError(message: "'match' statement cannot have more than one catch-all pattern")
        }
        else if !self.check(.rightBrace) {
            self.reportError(message: "Catch-all pattern must be the last clause in a 'match' statement")
        }
    }

    private func whileStatement(inverted: Bool)
    {
        let conditionLoop = self.currentLoopLocation()
        self.mustConsume(.leftParen, message: "Expected '(' to begin '\(inverted ? "until" : "while")' condition")
        self.expression()
        self.mustConsume(.rightParen, message: "Expected ')' to terminate '\(inverted ? "until" : "while")' condition")

        let afterBody = self.emitJump(inverted ? .jumpIfTrue : .jumpIfFalse)
        self.emitBytes(for: .pop)
        self.statement()

        self.emitLoop(backTo: conditionLoop)
        self.patchJump(at: afterBody)
        self.emitBytes(for: .pop)
    }

    /**
     Write the given `OpCode` -- which must be an instruction for a jump -- to
     the bytecode, followed by placeholder bytes for its operand.
     - returns: The location of the operand in the chunk's bytecode.
     */
    private func emitJump(_ opCode: OpCode) -> Int
    {
        assert([.jumpIfTrue, .jumpIfFalse, .jump, .jumpLong].contains(opCode), "Not a jump opcode: '\(opCode)'")
        // Since the destination address is not known at this point, the
        // placeholder must always be long
        let opCode: OpCode = (opCode == .jump) ? .jumpLong : opCode
        self.emitBytes(for: opCode)
        let location = self.chunk.code.count
        for _ in 0..<OpCode.longOperandSize {
            self.chunk.write(byte: 0xff, line: self.previousToken.lineNumber)
        }
        return location
    }

    /**
     Overwrite the placeholder jump operand at `location` in the bytecode with
     the distance from its own end to the current end of the bytecode, so that
     the jump will land on the next instruction to be compiled.
     */
    private func patchJump(at location: Int)
    {
        let address = self.chunk.code.count
        self.chunk.overwriteBytes(at: location, with: address)
    }

    private func emitLoop(backTo location: LoopLocation)
    {
        self.chunk.write(operation: .jump,
                          argument: location.address,
                              line: location.line)
    }

    private typealias LoopLocation = (address: Int, line: Int)
    private func currentLoopLocation() -> LoopLocation
    {
        return (self.chunk.code.count, self.currentToken.lineNumber)
    }

    private func expressionStatement()
    {
        self.expression()
        self.mustConsume(.semicolon, message: "Expected ';' to terminate expression")
        self.emitBytes(for: .pop)
    }

    //MARK:- Variable statements

    private func variableDeclaration()
    {
        let (isGlobal, place) = self.declareVarIdentifier(failureMessage: "Expected a variable name")
        let declarationLine = self.previousToken.lineNumber

        // Emit code for the initializer expression _first_ so that
        // the stack is set up for the definition.
        if self.match(.equal) {
            self.expression()
        }
        else {
            self.emitBytes(for: .nil)
        }
        self.mustConsume(.semicolon, message: "Expected ';' to terminate variable declaration")

        if isGlobal {
            self.chunk.write(operation: .defineGlobal,
                              argument: place,
                                  line: declarationLine)
        }
        else {
            self.locals.markLastInitialized(with: place)
            // No bytecode to emit; locals are just slots on the stack.
        }
    }

    /**
     Handle the identifier in a variable declaration, adding local or global
     storage as appropriate.
     - returns: If a global, the global's storage index; for a local, the `depth`
     of the current scope.
     */
    private func declareVarIdentifier(failureMessage: String) -> (isGlobal: Bool, place: Int)
    {
        self.mustConsume(.identifier, message: failureMessage)
        switch self.currentScope {
            case .global:
                let name = self.previousToken.lexeme.withCStringBuffer(self.copyOrInternString(_:))
                return (true, self.globals.index(for: name))
            case let .block(depth):
                self.addLocal(at: depth)
                return (false, depth)
        }
    }

    private func addLocal(at depth: Int)
    {
        let name = self.previousToken.lexeme
        guard !(self.locals.currentFrame(ifAt: depth).contains(where: { $0.name == name })) else {
            self.reportError(message: "Illegal redefinition of variable '\(name)'")
            return
        }

        let local = LocalVariables.Entry(name: name, depth: nil)
        do { try self.locals.append(local) }
        catch { self.reportError(message: "Local variable limit exceeded") }
    }

    private func inScope(_ body: () -> Void)
    {
        let depth = self.currentScope.increment()
        body()

        for _ in 0..<(self.locals.popFrame(at: depth)) {
            //TODO: Add `OpCode.popFrame` that takes an operand for the number
            // of pops; or even better, also add `pop(_ n: Int)` to `RawStack`.
            self.emitBytes(for: .pop)
        }
        self.currentScope.decrement()
    }

    /**
     Consume and handle tokens from the stream as long as the precedence rank of encountered
     tokens is higher than the starting `precedence`.
     */
    private func parse(fromPrecedence precedenceLimit: ParseRule.Precedence)
    {
        self.advance()

        // Compile the initial segment of the current expression
        guard let prefixParser = self.parseRule(for: self.previousToken.kind).prefix else {
            self.reportError(message: "Expected expression.")
            return
        }

        let canAssign = precedenceLimit <= .assignment
        prefixParser(canAssign)

        // Compile the remainder of the expression if the current token is an infix operation
        // of some kind and has sufficiently high precedence.
        var nextRule = self.parseRule(for: self.currentToken.kind)
        while precedenceLimit <= nextRule.precedence {
            self.advance()

            guard let infixParser = nextRule.infix else {
                fatalError("Misconfigured rule table: \(self.previousToken.kind) should have an infix rule")
            }

            infixParser()

            nextRule = self.parseRule(for: self.currentToken.kind)
        }
    }

    private func binary()
    {
        let operatorKind = self.previousToken.kind

        // Compile the right operand (will continue unless/until a higher precedence op is encountered)
        let precedence = self.parseRule(for: operatorKind).precedence
        self.parse(fromPrecedence: precedence.incremented())

        switch operatorKind {
            case .bangEqual: self.emitBytes(for: .equal, .not)
            case .equalEqual: self.emitBytes(for: .equal)
            case .greater: self.emitBytes(for: .greater)
            case .greaterEqual: self.emitBytes(for: .less, .not)
            case .less: self.emitBytes(for: .less)
            case .lessEqual: self.emitBytes(for: .greater, .not)
            case .minus: self.emitBytes(for: .subtract)
            case .plus: self.emitBytes(for: .add)
            case .star: self.emitBytes(for: .multiply)
            case .slash: self.emitBytes(for: .divide)
            default:
                fatalError("Token had non-binary Kind '\(operatorKind)'")
        }
    }

    private func literal()
    {
        switch self.previousToken.kind {
            case .nil:
                self.emitBytes(for: .nil)
            case .true:
                self.emitBytes(for: .true)
            case .false:
                self.emitBytes(for: .false)
            default:
                fatalError("Token is not a literal: \(self.previousToken)")
        }
    }

    private func grouping()
    {
        self.expression()
        self.mustConsume(.rightParen, message: "Expected ')' after expression.")
    }

    private func number()
    {
        guard let value = Double(self.previousToken.lexeme) else {
            fatalError("Failed to convert token '\(self.previousToken.lexeme)' to a Value")
        }
        self.emitConstant(value: .number(value), operation: .constant)
    }

    private func unary()
    {
        let operatorKind = self.previousToken.kind

        self.parse(fromPrecedence: .unary)

        switch operatorKind {
            case .bang: self.emitBytes(for: .not)
            case .minus: self.emitBytes(for: .negate)
            default:
                fatalError("Token had non-unary Kind '\(operatorKind)'")
        }
    }

    private func logical()
    {
        let jumpOp: OpCode
        let precedence: ParseRule.Precedence
        switch self.previousToken.kind {
            case .and:
                jumpOp = .jumpIfFalse
                precedence = .and
            case .or:
                jumpOp = .jumpIfTrue
                precedence = .or
            default:
                fatalError("Not a logical operator: \(self.previousToken.kind)")
        }

        let endJump = self.emitJump(jumpOp)

        self.emitBytes(for: .pop)
        self.parse(fromPrecedence: precedence)

        self.patchJump(at: endJump)
    }

    //MARK:- Variable references

    private func variable(_ canAssign: Bool)
    {
        self.namedVariable(canAssign)
    }

    private func namedVariable(_ canAssign: Bool)
    {
        let identifierLine = self.previousToken.lineNumber

        let (isLocal, index) = self.resolveVariableName(self.previousToken.lexeme)

        let operation: OpCode
        if self.match(.equal) {
            guard canAssign else {
                return self.reportError(at: self.previousToken,
                                   message: "Invalid assignment target")
            }
            self.expression()
            operation = isLocal ? .setLocal : .setGlobal
        }
        else {
            operation = isLocal ? .readLocal : .readGlobal
        }

        self.chunk.write(operation: operation,
                          argument: index,
                              line: identifierLine)
    }

    private func resolveVariableName(_ name: Substring) -> (isLocal: Bool, slot: Int)
    {
        // Locals take priority and thus can shadow globals.
        switch self.locals.resolve(name) {
            case .failure(_):
                self.reportError(message: "Cannot access variable '\(name)' in its own initializer.")
                return (true, 0)  // Will never be executed
            case let .success(.some(localIndex)):
                return (true, localIndex)
            case .success(nil):
                let interned = name.withCStringBuffer(self.copyOrInternString(_:))
                // It's okay if this doesn't exist yet: we could be in a function body
                // that won't execute until after the global is defined.
                let globalIndex = self.globals.index(for: interned)
                return (false, globalIndex)
        }
    }

    //MARK:- Strings

    private func string()
    {
        let lexeme = self.previousToken.lexeme
        // Drop quote marks
        let firstCharIndex = lexeme.index(after: lexeme.startIndex)
        let endQuoteIndex = lexeme.index(lexeme.endIndex, offsetBy: -1)
        let contents = lexeme[firstCharIndex..<endQuoteIndex]

        // We incur an unnecessary copy into a temporary here when the string has no
        // escapes. This matches the Wren implementation (wren_compiler.c -> readString)
        // so we won't worry about it for now. At some point, though, it would be good
        // to compare the performance of scanning the string for backslashes first and
        // skipping rendering if it's not needed -- we'd get a pointer to the String's
        // contents (`withCString`) and copy from that directly.
        do {
            let object: StringRef = try self.stringCompiler.withRenderedEscapes(in: contents,
                                                                                self.copyOrInternString(_:))
            self.emitConstant(value: .object(object.asBaseRef()))
        }
        catch let error as StringEscapeError {
            self.reportError(message: error.message)
        }
        catch {
            assertionFailure("Unexpected error from string compilation: '\(error)'")
            self.reportError(message: "Could not compile string contents: '\(error)'")
        }
    }

    /**
     Look up the given string in the global `strings` table and return the
     existing instance if found; otherwise initialize and return a new
     `StringRef`, inserting it into `strings` first.
     */
    private func copyOrInternString(_ string: ConstCStr) -> StringRef
    {
        if let existing = self.strings.findString(matching: string) {
            return existing
        }
        else {
            let new = self.allocator.createString(copying: string)
            self.strings.internString(new)
            return new
        }
    }

    //MARK:- Chunk handling

    private func emitReturn()
    {
        self.emitBytes(for: .return)
    }

    private func emitConstant(value: Value, operation: OpCode = .constant, line: Int? = nil)
    {
        let success = self.chunk.write(constant: value,
                                      operation: operation,
                                           line: line ?? self.previousToken.lineNumber)
        if !(success) {
            self.reportError(message: "Constant storage limit exceeded.")
        }
    }

    private func emitBytes(for opCodes: OpCode..., line: Int? = nil)
    {
        for code in opCodes {
            self.chunk.write(opCode: code, line: line ?? self.previousToken.lineNumber)
        }
    }

    //MARK:- Error handling

    /**
     Scan and discard tokens until an apparent statement boundary, then
     reset the `state` from `.panic`.
     */
    private func synchronize()
    {
        defer { self.state.synchronize() }
        while self.currentToken.kind != .EOF {
            // We want to restart at the beginning of the next statement-like thing,
            // which means the token _after_ a semicolon...
            guard self.previousToken.kind != .semicolon else { return }

            switch self.currentToken.kind {
                // or _on_ an appropriate keyword.
                case .class, .fun, .var, .for, .if, .while, .print, .return:
                    return
                default:
                    break
            }

            self.advance()
        }
    }

    private func reportErrorAtCurrent<S : StringProtocol>(message: S)
    {
        self.reportError(at: self.currentToken, message: message)
    }

    private func reportError<S : StringProtocol>(message: S)
    {
        self.reportError(at: self.previousToken, message: message)
    }

    private func reportError<S : StringProtocol>(at token: Token, message: S)
    {
        guard self.state != .panic else { return }

        self.state.recordError()

        let location: String
        switch token.kind {
            case .EOF: location = " at end"
            case .error: location = ""
            default: location = " at '\(token.lexeme)'"
        }

        StdErr.print("\(token.lineNumber): error:\(location) \(message)")
    }
}

/** Description of handling for a particular token kind. */
private struct ParseRule
{
    enum Precedence : CaseIterable, Comparable
    {
        case none, joined, assignment, or, and, equality, comparison, term, factor, unary, call, primary

        func incremented() -> Precedence
        {
            let cases = Self.allCases
            let index = cases.firstIndex(of: self)!
            let nextIndex = cases.index(after: index)
            guard nextIndex != cases.endIndex else { return .primary }
            return cases[nextIndex]
        }
    }

    /**
     A `Compiler` method that parses an expression where assignments can be handled.
     - parameter canAssign: Whether the current parsing context is permitted to be part of
     an assignment statement (either a variable or an object setter).
     */
    typealias AssignmentParseFunc = (_ canAssign: Bool) -> Void
    /**
     A `Compiler` method that parses an expression where assignments are not
     syntactically allowed.
     */
    typealias ParseFunc = () -> Void

    /**
     Parsing method to be called when the token is found at the beginning of an expression.
     - remark: Most parse methods actually do not need the `canAssign` flag; it will be
     swallowed in that case (see `init(nonassigningPrefix:infix:precedence:)`
     */
    let prefix: AssignmentParseFunc?
    /** Parsing method to be called when the token is found inside an expression. */
    let infix: ParseFunc?
    /**
     Infix precedence for the token, controlling how much of the token stream will be parsed
     into the operand.
     */
    let precedence: Precedence
}

private extension Compiler
{
    func parseRule(for kind: Token.Kind) -> ParseRule
    {
        // Note that any rule lacking an infix parser will also have the lowest possible precedence
        switch kind {
            case .leftParen    : return ParseRule(nonassigningPrefix: self.grouping, infix: nil, precedence: .call)
            case .rightParen   : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .leftBrace    : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .rightBrace   : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .colon        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .comma        : return ParseRule(prefix: nil, infix: self.expression, precedence: .joined)
            case .dot          : return ParseRule(prefix: nil, infix: nil, precedence: .call)
            case .semicolon    : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .minus        : return ParseRule(nonassigningPrefix: self.unary, infix: self.binary, precedence: .term)
            case .plus         : return ParseRule(prefix: nil, infix: self.binary, precedence: .term)
            case .slash        : return ParseRule(prefix: nil, infix: self.binary, precedence: .factor)
            case .star         : return ParseRule(prefix: nil, infix: self.binary, precedence: .factor)
            case .arrow        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .bang         : return ParseRule(nonassigningPrefix: self.unary, infix: nil, precedence: .none)
            case .bangEqual    : return ParseRule(prefix: nil, infix: self.binary, precedence: .equality)
            case .equal        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .equalEqual   : return ParseRule(prefix: nil, infix: self.binary, precedence: .equality)
            case .greater      : return ParseRule(prefix: nil, infix: self.binary, precedence: .comparison)
            case .greaterEqual : return ParseRule(prefix: nil, infix: self.binary, precedence: .comparison)
            case .less         : return ParseRule(prefix: nil, infix: self.binary, precedence: .comparison)
            case .lessEqual    : return ParseRule(prefix: nil, infix: self.binary, precedence: .comparison)
            case .identifier   : return ParseRule(prefix: self.variable, infix: nil, precedence: .none)
            case .string       : return ParseRule(nonassigningPrefix: self.string, infix: nil, precedence: .none)
            case .number       : return ParseRule(nonassigningPrefix: self.number, infix: nil, precedence: .none)
            case .and          : return ParseRule(prefix: nil, infix: self.logical, precedence: .and)
            case .break        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .class        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .else         : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .false        : return ParseRule(nonassigningPrefix: self.literal, infix: nil, precedence: .none)
            case .for          : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .fun          : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .if           : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .match        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .nil          : return ParseRule(nonassigningPrefix: self.literal, infix: nil, precedence: .none)
            case .or           : return ParseRule(prefix: nil, infix: self.logical, precedence: .or)
            case .print        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .return       : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .super        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .this         : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .true         : return ParseRule(nonassigningPrefix: self.literal, infix: nil, precedence: .none)
            case .unless       : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .until        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .var          : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .while        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .error        : return ParseRule(prefix: nil, infix: nil, precedence: .none)
            case .EOF          : return ParseRule(prefix: nil, infix: nil, precedence: .none)
        }
    }
}

private extension ParseRule
{
    /** Create a parse rule for a token type that does not need the `canAssign` flag. */
    init(nonassigningPrefix: ParseFunc?, infix: ParseFunc?, precedence: Precedence)
    {
        // Ignore the boolean `canAssign` flag
        self.prefix = nonassigningPrefix.map({ (parse) in { (_) in parse() } })
        self.infix = infix
        self.precedence = precedence
    }
}

private extension Compiler.State
{
    /** Change the state to reflect a parse error having been encountered. */
    mutating func recordError()
    {
        switch self {
            case .normal, .error:
                self = .panic
            case .panic:
                return
        }
    }

    /** If currently in panic mode, return to reporting errors. */
    mutating func synchronize()
    {
        switch self {
            case .normal, .error:
                return
            case .panic:
                self = .error
        }
    }
}

private extension Token
{
    /** Placeholder token for the compiler state before compilation begins. */
    static var dummy: Token
    {
        return Token(kind: .EOF, lexeme: "not a token", lineNumber: -1)
    }

    /**
     Whether this is a `Token` for a '_' pattern, matching any value.
     */
    var isWildcard: Bool
    {
        self.kind == .identifier && self.lexeme == "_"
    }
}

private extension StringProtocol
{
    /**
     Invoke `body` with a buffer pointer to the NUL-terminated UTF-8 contents
     of the string.
     - remark: The buffer's `count` includes the NUL character.
     */
    func withCStringBuffer<Result>(_ body: (ConstCStr) -> Result) -> Result
    {
        self.withCString { (chars) -> Result in
            body(ConstCStr(start: chars, count: self.utf8.count + 1))
        }
    }
}
