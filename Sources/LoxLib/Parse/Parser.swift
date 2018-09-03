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
            if self.matchAny(.fun) {
                guard self.check(.identifier) else {
                    self.backtrack()
                    return try self.statement()
                }
                return try self.functionDecl("function")
            }
            if self.matchAny(.var) {
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

    /**
     Parse a function or method declaration. The `kind` argument describes which,
     for error reporting.
     */
    private func functionDecl(_ kind: String) throws -> Statement
    {
        try self.mustConsume(.identifier, message: "Missing name for \(kind).")
        let ident = previous

        let (parameters, body) = try self.finishFunction(kind)
        return .functionDecl(identifier: ident, parameters: parameters, body: body)
    }

    private func anonFunction() throws -> Expression
    {
        let (parameters, body) = try self.finishFunction("function")
        return .anonFunction(id: self.index, parameters: parameters, body: body)
    }

    private func finishFunction(_ kind: String) throws -> ([Token], [Statement])
    {
        try self.mustConsume(.leftParen, message: "Expected '(' to start parameter list.")

        let parameters = try self.parameters()

        try self.mustConsume(.leftBrace, message: "Expected '{' to start \(kind) body.")

        let body = try self.finishBlock()

        return (parameters, body)
    }

    private func parameters() throws -> [Token]
    {
        guard !(self.matchAny(.rightParen)) else { return [] }

        var parameters: [Token] = []
        repeat {
            try self.mustConsume(.identifier, message: "Expected parameter name.")
            parameters.append(self.previous)
        } while self.matchAny(.comma)

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
        try self.mustConsume(.identifier,
                             message: "Expected an identifier in variable declaration.")

        let name = self.previous

        let initializer = self.matchAny(.equal) ? try self.expression() : nil

        try self.mustConsume(.semicolon,
                             message: "Expected ';' after variable declaration.")

        return .variableDecl(name: name, initializer: initializer)
    }

    private func statement() throws -> Statement
    {
        if self.matchAny(.for) {
            return try self.finishForStatement()
        }

        if self.matchAny(.if, .unless) {
            return try self.finishIfStatement()
        }

        if self.matchAny(.print) {
            return try self.finishPrintStatement()
        }

        if self.matchAny(.return) {
            return try self.finishReturnStatement()
        }

        if self.matchAny(.while, .until) {
            return try self.finishLoopStatement()
        }

        if self.matchAny(.break) {
            return try self.finishBreakStatement()
        }

        if self.matchAny(.leftBrace) {
            return try .block(self.finishBlock())
        }

        return try self.expressionStatement()
    }

    private func finishForStatement() throws -> Statement
    {
        try self.mustConsume(.leftParen, message: "Expected '(' after 'for'.")

        let initializer: Statement?
        if self.matchAny(.semicolon) {
            initializer = nil
        }
        else if self.matchAny(.var) {
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
        let elseBranch = self.matchAny(.else) ? try self.statement() : nil

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
        if self.matchAny(.comma) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.joined()
        }

        var expr = try self.assignment()

        if self.isInArgumentList && !(self.parenState.isNested) {
            return expr
        }

        while self.matchAny(.comma) {
            let op = self.previous
            let right = try self.assignment()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func assignment() throws -> Expression
    {
        if self.matchAny(.equal) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.assignment()
        }

        // We do not want to use arbitrary-length lookahead here to validate
        // the assignment right off the bat. Instead, we parse the left-hand
        // side first...
        let lvalue = try self.or()

        guard self.matchAny(.equal) else {
            return lvalue
        }

        // then look*behind* to make sure we have a valid assignment target
        guard case let .variable(name, resolution: _) = lvalue else {
            self.reportParseError(message: "Invalid lvalue in assignment")
            return lvalue
        }

        let rvalue = try self.assignment()

        return .assignment(name: name, value: rvalue, resolution: ScopeResolution())
    }

    private func or() throws -> Expression
    {
        if self.matchAny(.or) {
            self.reportParseError(message: "Missing lefthand expression.")
            return try self.or()
        }

        var expr = try self.and()

        while self.matchAny(.or) {
            let op = self.previous
            let right = try self.and()
            expr = .logical(left: expr, op: op, right: right)
        }

        return expr
    }

    private func and() throws -> Expression
    {
        if self.matchAny(.and) {
            self.reportParseError(message: "Missing lefthand expression.")
            return try self.and()
        }

        var expr = try self.equality()

        while self.matchAny(.and) {
            let op = self.previous
            let right = try self.equality()
            expr = .logical(left: expr, op: op, right: right)
        }

        return expr
    }

    private func equality() throws -> Expression
    {
        if self.matchAny(.bangEqual, .equalEqual) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.equality()
        }

        var expr = try self.comparison()

        while self.matchAny(.bangEqual, .equalEqual) {
            let op = self.previous
            let right = try self.comparison()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func comparison() throws -> Expression
    {
        if self.matchAny(.greater, .greaterEqual, .less, .lessEqual) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.comparison()
        }

        var expr = try self.addition()

        while self.matchAny(.greater, .greaterEqual, .less, .lessEqual) {
            let op = self.previous
            let right = try self.addition()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func addition() throws -> Expression
    {
        if self.matchAny(.plus) {
            self.reportParseError(message: "Missing lefthand expression")
            return try self.addition()
        }

        var expr = try self.multiplication()

        while self.matchAny(.minus, .plus) {
            let op = self.previous
            let right = try self.multiplication()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func multiplication() throws -> Expression
    {
        var expr = try self.unary()

        while self.matchAny(.slash, .star) {
            let op = self.previous
            let right = try self.unary()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func unary() throws -> Expression
    {
        guard self.matchAny(.bang, .minus) else {
            return try self.call()
        }

        let op = self.previous
        let subexpr = try self.unary()
        return .unary(op: op, subexpr)
    }

    private func call() throws -> Expression
    {
        var expr = try self.primary()

        //TODO: This loop will make more sense when dot expressions are added
        while true {
            guard self.matchAny(.leftParen) else { break }
            expr = try self.finishCall(to: expr)
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
            } while self.matchAny(.comma)
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
        if self.matchAny(.false) { return .literal(.bool(false)) }
        if self.matchAny(.true) { return .literal(.bool(true)) }
        if self.matchAny(.nil) { return .literal(.nil) }

        if self.matchAny(.number, .string) {
            return .literal(self.previous.literal!)
        }

        if self.matchAny(.identifier) {
            return .variable(self.previous, resolution: ScopeResolution())
        }

        if self.matchAny(.fun) {
            return try self.anonFunction()
        }

        if self.matchAny(.leftParen) {
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

    private func matchAny(_ kinds: Token.Kind...) -> Bool
    {
        for kind in kinds {
            if self.check(kind) {
                self.advance()
                return true
            }
        }

        return false
    }

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

    private func reportParseError(message: String)
    {
        let token = self.peek()
        let locationDescription = token.kind == .EOF ? "end" : "'\(token.lexeme)'"
        Lox.report(at: token.line,
             location: "at \(locationDescription)",
              message: message)
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
