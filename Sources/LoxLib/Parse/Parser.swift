import Foundation

class Parser
{
    private let tokens: [Token]
    private var index: Int = 0

    /**
     Track levels of parentheses so that commas inside argument lists
     can be parsed correctly.
     */
    private var parenState = NestingCounter()

    /**
     Flag indicating that we are parsing a function call's argument list.
     - remark: This is required to handle commas correctly, given the
     existence of 'joined' expressions.
     */
    private var isInArgumentList = false

    private var isAtEnd: Bool
    {
        return self.peek().kind == .EOF
    }

    private var previous: Token
    {
        return self.tokens[self.index - 1]
    }

    init(tokens: [Token])
    {
        self.tokens = tokens
    }

    func parse() -> [Statement]?
    {
        var statements: [Statement] = []

        while !(self.isAtEnd) {
            guard let decl = self.declaration() else {
                continue
            }
            statements.append(decl)
        }

        return statements

    }

    //MARK:- Grammar rules

    private func declaration() -> Statement?
    {
        do {
            if self.match(.class) {
                return try self.classDecl()
            }
            else if let production = self.match(.fun, orTypo: .func) {
                guard self.check(.identifier) else {
                    // Anonymous function statment expression
                    self.backtrack()
                    return try self.statement()
                }
                if case let .error(typo) = production {
                    self.reportTypo(typo)
                }
                return try self.functionDecl(.function)
            }
            else if self.match(.var) {
                return try self.variableDecl()
            }
            else {
                return try self.statement()
            }
        }
        catch {
            if let parseError = error as? ParseError {
                self.reportParseError(message: parseError.message)
            }
            self.synchronize()
            return nil
        }
    }

    private func classDecl() throws -> Statement
    {
        try self.mustConsume(.identifier, message: "Missing class name")
        let name = self.previous
        try self.mustConsume(.leftBrace, message: "Expected '{' to begin class body")

        var methods: [Statement] = []
        while !(self.check(.rightBrace)) && !(self.isAtEnd) {
            methods.append(try self.functionDecl(.method))
        }

        try self.mustConsume(.rightBrace, message: "Expected '}' to close class body")

        return .classDecl(name: name, methods: methods)
    }

    /**
     Parse a function or method declaration. The `kind` argument describes which,
     for error reporting.
     */
    private func functionDecl(_ kind: FuncKind) throws -> Statement
    {
        try self.mustConsume(.identifier, message: "Missing name for \(kind).")
        let ident = self.previous

        let (parameters, body) = try self.finishFunction(kind)
        return .functionDecl(identifier: ident, parameters: parameters, body: body)
    }

    private func anonFunction() throws -> Expression
    {
        let (parameters, body) = try self.finishFunction(.function)
        return .anonFunction(id: self.index, parameters: parameters, body: body)
    }

    private func finishFunction(_ kind: FuncKind) throws -> ([Token], [Statement])
    {
        try self.mustConsume(.leftParen, message: "Expected '(' to start parameter list.")

        let parameters = try self.parameters()

        try self.mustConsume(.leftBrace, message: "Expected '{' to start \(kind) body.")

        let body = try self.finishBlock()

        return (parameters, body)
    }

    private func parameters() throws -> [Token]
    {
        guard !(self.match(.rightParen)) else { return [] }

        var parameters: [Token] = []
        repeat {
            if self.match(.this, .super) {
                self.reportIllegalObjectRef()
            }
            else {
                try self.mustConsume(.identifier, message: "Expected parameter name.")
            }
            parameters.append(self.previous)
        } while self.match(.comma)

        if parameters.count >= Config.maxFunctionArity {
            self.reportParseError(
                message: "Cannot have a more than \(Config.maxFunctionArity) parameters"
            )
            // Note that they are parsed anyways
        }

        try self.mustConsume(.rightParen, message: "Expected ')' to terminate parameter list.")

        return parameters
    }

    private func variableDecl() throws -> Statement
    {
        if self.match(.this, .super) {
            self.reportIllegalObjectRef()
        }
        else {
            try self.mustConsume(.identifier,
                                 message: "Expected an identifier in variable declaration.")
        }

        let name = self.previous

        let initializer = self.match(.equal) ? try self.expression() : nil

        try self.mustConsume(.semicolon,
                             message: "Expected ';' after variable declaration.")

        return .variableDecl(name: name, initializer: initializer)
    }

    private func statement() throws -> Statement
    {
        if self.match(.for) {
            return try self.finishForStatement()
        }

        if self.match(.if, .unless) {
            return try self.finishIfStatement()
        }

        if self.match(.print) {
            return try self.finishPrintStatement()
        }

        if self.match(.return) {
            return try self.finishReturnStatement()
        }

        if self.match(.while, .until) {
            return try self.finishLoopStatement()
        }

        if self.match(.break) {
            return try self.finishBreakStatement()
        }

        if self.match(.leftBrace) {
            return try .block(self.finishBlock())
        }

        return try self.expressionStatement()
    }

    private func finishForStatement() throws -> Statement
    {
        try self.mustConsume(.leftParen, message: "Expected '(' after 'for'.")

        let initializer: Statement?
        if self.match(.semicolon) {
            initializer = nil
        }
        else if self.match(.var) {
            initializer = try self.variableDecl()
        }
        else {
            initializer = try self.expressionStatement()
        }

        let condition = self.check(.semicolon) ? .literal(.bool(true)) : try self.expression()
        try self.mustConsume(.semicolon, message: "Expected ';' after loop condition.")

        let increment = self.check(.rightParen) ? nil : try self.expression()
        try self.mustConsume(.rightParen, message: "Expected ')' to terminate 'for' clauses.")

        var body = try self.statement()
        if let increment = increment {
            body = .block([body, .expression(increment)])
        }
        body = .loop(condition: condition, body: body)
        if let initializer = initializer {
            body = .block([initializer, body])
        }

        return body
    }

    private func finishIfStatement() throws -> Statement
    {
        let negated = (self.previous.kind == .unless)
        let statementLine = self.previous.line
        let parenMessage = "Parenthesized condition required for '\(negated ? "unless" : "if")'"

        try self.mustConsume(.leftParen, message: parenMessage)
        var condition = try self.expression()
        if negated {
            let bang = Token.bang(at: statementLine)
            condition = .unary(op: bang, condition)
        }
        try self.mustConsume(.rightParen, message: parenMessage)

        let thenBranch = try self.statement()
        let elseBranch = self.match(.else) ? try self.statement() : nil

        if negated && elseBranch != nil {
            self.reportParseError(message: "'unless' cannot have an 'else' clause.")
        }

        return .conditional(condition, then: thenBranch, else: elseBranch)
    }

    private func finishPrintStatement() throws -> Statement
    {
        let expression = try self.expression()
        try self.mustConsume(.semicolon,
                             message: "Expected ';' to terminate print statement.")
        return .print(expression)
    }

    private func finishReturnStatement() throws -> Statement
    {
        let token = self.previous
        let value = self.check(.semicolon) ? nil : try self.expression()
        try self.mustConsume(.semicolon,
                             message: "Expected ';' to termianate return statement.")

        return .return(token, value: value)
    }

    private func finishLoopStatement() throws -> Statement
    {
        let negated = (self.previous.kind == .until)
        let statementLine = self.previous.line
        let parenMessage = "Parenthesized condition required for '\(negated ? "until" : "while")'"

        try self.mustConsume(.leftParen, message: parenMessage)
        var condition = try self.expression()
        if negated {
            let bang = Token.bang(at: statementLine)
            condition = .unary(op: bang, condition)
        }
        try self.mustConsume(.rightParen, message: parenMessage)

        let body = try self.statement()

        return .loop(condition: condition, body: body)
    }

    private func finishBreakStatement() throws -> Statement
    {
        let token = self.previous
        try self.mustConsume(.semicolon, message: "Unterminated 'break' statement.")

        return .breakLoop(token)
    }

    private func finishBlock() throws -> [Statement]
    {
        var statements: [Statement] = []

        while !(self.check(.rightBrace)) && !(self.isAtEnd) {
            guard let declaration = self.declaration() else {
                continue
            }
            statements.append(declaration)
        }

        try self.mustConsume(.rightBrace, message: "Expected '}' to terminate block.")
        return statements
    }

    private func expressionStatement() throws -> Statement
    {
        let expression = try self.expression()
        try self.mustConsume(.semicolon,
                             message: "Expected ';' to terminate expression.")
        return .expression(expression)
    }

    private func expression() throws -> Expression
    {
        return try self.joined()
    }

    private func joined() throws -> Expression
    {
        if self.match(.comma) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.joined()
        }

        var expr = try self.assignment()

        if self.isInArgumentList && !(self.parenState.isNested) {
            return expr
        }

        while self.match(.comma) {
            let op = self.previous
            let right = try self.assignment()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func assignment() throws -> Expression
    {
        if self.match(.equal) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.assignment()
        }

        // We do not want to use arbitrary-length lookahead here to validate
        // the assignment right off the bat. Instead, we parse the left-hand
        // side first...
        let lvalue = try self.or()

        guard self.match(.equal) else {
            return lvalue
        }

        // then look*behind* to make sure we have a valid assignment target
        if case let .variable(name, resolution: _) = lvalue {
            let rvalue = try self.assignment()
            return .assignment(name: name, value: rvalue, resolution: ScopeResolution())
        }
        else if case let .get(object: object, member: member) = lvalue {
            let rvalue = try self.assignment()
            return .set(object: object, member: member, value: rvalue)
        }
        else {
            self.reportParseError(message: "Invalid lvalue in assignment")
            return lvalue
        }
    }

    private func or() throws -> Expression
    {
        if self.match(.or) {
            self.reportParseError(message: "Missing lefthand expression.")
            return try self.or()
        }

        var expr = try self.and()

        while self.match(.or) {
            let op = self.previous
            let right = try self.and()
            expr = .logical(left: expr, op: op, right: right)
        }

        return expr
    }

    private func and() throws -> Expression
    {
        if self.match(.and) {
            self.reportParseError(message: "Missing lefthand expression.")
            return try self.and()
        }

        var expr = try self.equality()

        while self.match(.and) {
            let op = self.previous
            let right = try self.equality()
            expr = .logical(left: expr, op: op, right: right)
        }

        return expr
    }

    private func equality() throws -> Expression
    {
        if self.match(.bangEqual, .equalEqual) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.equality()
        }

        var expr = try self.comparison()

        while self.match(.bangEqual, .equalEqual) {
            let op = self.previous
            let right = try self.comparison()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func comparison() throws -> Expression
    {
        if self.match(.greater, .greaterEqual, .less, .lessEqual) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.comparison()
        }

        var expr = try self.addition()

        while self.match(.greater, .greaterEqual, .less, .lessEqual) {
            let op = self.previous
            let right = try self.addition()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func addition() throws -> Expression
    {
        if self.match(.plus) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.addition()
        }

        var expr = try self.multiplication()

        while self.match(.minus, .plus) {
            let op = self.previous
            let right = try self.multiplication()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func multiplication() throws -> Expression
    {
        var expr = try self.unary()

        while self.match(.slash, .star) {
            let op = self.previous
            let right = try self.unary()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func unary() throws -> Expression
    {
        guard self.match(.bang, .minus) else {
            return try self.call()
        }

        let op = self.previous
        let subexpr = try self.unary()
        return .unary(op: op, subexpr)
    }

    private func call() throws -> Expression
    {
        var expr = try self.primary()

        while true {
            if self.match(.leftParen) {
                expr = try self.finishCall(to: expr)
            }
            else if self.match(.dot) {
                try self.mustConsume(.identifier,
                                     message: "Expected member name after '.'")
                expr = .get(object: expr, member: self.previous)
            }
            else {
                break
            }
        }

        return expr
    }

    private func finishCall(to callee: Expression) throws -> Expression
    {
        var arguments: [Expression] = []

        if !self.check(.rightParen) {

            self.isInArgumentList = true
            defer { self.isInArgumentList = false }

            repeat {
                arguments.append(try self.expression())
            } while self.match(.comma)
        }

        if arguments.count > Config.maxFunctionArity {
            self.reportParseError(
                message: "Cannot have a more than \(Config.maxFunctionArity) arguments"
            )
            // Note that they are parsed anyways
        }

        try self.mustConsume(.rightParen, message: "Missing closing ')' for argument list.")

        return .call(callee, paren: self.previous, arguments: arguments)
    }

    private func primary() throws -> Expression
    {
        if self.match(.false) { return .literal(.bool(false)) }
        if self.match(.true) { return .literal(.bool(true)) }
        if self.match(.nil) { return .literal(.nil) }
        if self.match(.this) { return .this(self.previous, resolution: ScopeResolution()) }

        if self.match(.number, .string) {
            return .literal(self.previous.literal!)
        }

        if let production = self.match(.fun, orTypo: .func) {
            if case let .error(typo) = production {
                self.reportTypo(typo)
            }
            return try self.anonFunction()
        }

        if self.match(.identifier) {
            return .variable(self.previous, resolution: ScopeResolution())
        }

        if self.match(.leftParen) {
            self.parenState++
            defer { self.parenState-- }

            let expr = try self.expression()
            try self.mustConsume(.rightParen,
                                 message: "Expected ')' to match earlier '('")
            return .grouping(expr)
        }

        throw ParseError(message: "No expression found")
    }

    //MARK:- Utility

    private func match(_ kinds: Token.Kind...) -> Bool
    {
        for kind in kinds {
            if self.check(kind) {
                self.advance()
                return true
            }
        }

        return false
    }

    /**
     The result of checking for a valid token or a related typo that can each
     occur at the the same point in the parse tree.
     */
    private enum Production
    {
        /** The expected token type was found. */
        case correct
        /**
         The related typo was found. It is embedded for ease of error reporting.
         */
        case error(Typo)
    }

    /**
     Test first for an expected `Token.Kind`, then for a related error.
     - returns: The result of comparing the current token, or `nil` if
     neither the `Token.Kind` nor the `Typo` matched.
     */
    private func match(_ token: Token.Kind, orTypo typo: Typo) -> Production?
    {
        if self.match(token) {
            return .correct
        }
        else if self.matchTypo(typo) {
            return .error(typo)
        }
        else {
            return nil
        }
    }

    /** Consume the current token if it matches the given mistake. */
    private func matchTypo(_ typo: Typo) -> Bool
    {
        guard !(self.isAtEnd) else { return false }

        let token = self.peek()
        guard token.kind == .identifier && token.lexeme == typo.lexeme else {
            return false
        }

        self.advance()
        return true
    }

    /**
     Test that the current token is of the given `Kind`.
     - parameter kind: The kind of token to match.
     */
    private func check(_ kind: Token.Kind) -> Bool
    {
        guard !(self.isAtEnd) else { return false }
        return self.peek().kind == kind
    }

    private func peek() -> Token
    {
        return self.tokens[self.index]
    }

    private func advance()
    {
        self.index += 1
    }

    private func backtrack()
    {
        self.index -= 1
    }

    //MARK:- Error handling

    /** Consume the next token if it matches `kind` or else report an error. */
    private func mustConsume(_ kind: Token.Kind, message: String) throws
    {
        guard self.check(kind) else {
            throw ParseError(message: message)
        }

        self.advance()
    }

    private func reportParseError(at token: Token? = nil, message: String)
    {
        let token = token ?? self.peek()
        let locationDescription = token.kind == .EOF ? "end" : "'\(token.lexeme)'"
        Lox.report(at: token.line,
             location: "at \(locationDescription)",
              message: message)
    }

    private func reportIllegalObjectRef()
    {
        let message = "Cannot use keyword '\(self.previous.lexeme)' as an identifier"
        self.reportParseError(at: self.previous, message: message)
    }

    private func reportTypo(_ typo: Typo)
    {
        self.reportParseError(message: typo.message)
    }

    /**
     Step forward through a statement that has failed to parse, resuming when
     the parsing is likely to begin at a new statement, so that we can
     continue to report as many errors as possible.
     */
    private func synchronize()
    {
        while !self.isAtEnd {

            self.advance()

            // Moved past problematic statement
            if self.previous.kind == .semicolon { return }

            switch self.peek().kind {
                case .class: fallthrough
                case .fun: fallthrough
                case .var: fallthrough
                case .for: fallthrough
                case .if: fallthrough
                case .while: fallthrough
                case .print: fallthrough
                case .return:
                    return
                default:
                    continue
            }
        }
    }

    private struct ParseError : Error
    {
        let message: String
    }
}
