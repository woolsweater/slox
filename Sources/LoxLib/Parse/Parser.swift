import Foundation

class Parser
{
    private let tokens: [Token]
    private var index: Int = 0

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
            if self.matchAny(.var) {
                return try self.variableDecl()
            }
            else {
                return try self.statement()
            }
        }
        catch {
            self.synchronize()
            return nil
        }
    }

    private func variableDecl() throws -> Statement
    {
        try self.mustConsume(.identifier, message: "Expected an identifier in variable declaration.")

        let name = self.previous

        let initializer = self.matchAny(.equal) ? try self.expression() : nil

        try self.mustConsume(.semicolon, message: "Expected ';' after variable declaration.")

        return .variableDecl(name: name, initializer: initializer)
    }

    private func statement() throws -> Statement
    {
        if self.matchAny(.print) {
            return try self.finishPrintStatement()
        }

        if self.matchAny(.leftBrace) {
            return try .block(self.finishBlock())
        }

        return try self.finishExpressionStatement()
    }

    private func finishPrintStatement() throws -> Statement
    {
        let expression = try self.expression()
        try self.mustConsume(.semicolon,
                             message: "Expected ';' to terminate print statement.")
        return .print(expression)
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

    private func finishExpressionStatement() throws -> Statement
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
            _ = self.reportParseError(message: "Missing lefthand expression")
            return try self.joined()
        }

        var expr = try self.assignment()

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
            _ = self.reportParseError(message: "Missing lefthand expression")
            return try self.assignment()
        }

        // We do not want to use lookahead here to validate the assignment
        // right off the bat. Instead, we parse the left-hand side first.
        let lvalue = try self.equality()

        guard self.matchAny(.equal) else {
            return lvalue
        }

        // Then look*behind* to make sure we have a valid assignment target
        guard case let .variable(name: name) = lvalue else {
            _ = self.reportParseError(message: "Invalid lvalue in assignment")
            return lvalue
        }

        let rvalue = try self.assignment()

        return .assignment(name: name, value: rvalue)
    }

    private func equality() throws -> Expression
    {
        if self.matchAny(.bangEqual, .equalEqual) {
            _ = self.reportParseError(message: "Missing lefthand expression")
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
            _ = self.reportParseError(message: "Missing lefthand expression")
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
            _ = self.reportParseError(message: "Missing lefthand expression")
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
            return try self.primary()
        }

        let op = self.previous
        let subexpr = try self.unary()
        return .unary(op: op, subexpr)
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
            return .variable(self.previous)
        }

        if self.matchAny(.leftParen) {
            let expr = try self.expression()
            try self.mustConsume(.rightParen,
                                 message: "Expected ')' to match earlier '('")
            return .grouping(expr)
        }

        throw self.reportParseError(message: "No expression found")
    }

    //MARK:- Utility

    private func matchAny(_ kinds: Token.Kind...) -> Bool
    {
        for kind in kinds {
            if self.check(kind) {
                self.advanceIndex()
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

    private func advanceIndex()
    {
        self.index += 1
    }

    //MARK:- Error handling

    /** Consume the next token if it matches `kind` or else report an error. */
    private func mustConsume(_ kind: Token.Kind, message: String) throws
    {
        guard self.check(kind) else {
            throw self.reportParseError(message: message)
        }

        self.advanceIndex()
    }

    private func reportParseError(message: String) -> ParseError
    {
        let token = self.peek()
        let locationDescription = token.kind == .EOF ? "end" : "'\(token.lexeme)'"
        Lox.report(at: token.line,
             location: "at \(locationDescription)",
              message: message)
        return ParseError()
    }

    /**
     Step forward through a statement that has failed to parse, resuming when
     the parsing is likely to begin at a new statement, so that we can
     continue to report as many errors as possible.
     */
    private func synchronize()
    {
        while !self.isAtEnd {
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
                    self.advanceIndex()
            }
        }
    }

    private struct ParseError : Error {}
}

