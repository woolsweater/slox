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

    func parse() -> Expr?
    {
        let expr: Expr

        do { expr = try self.expression() }
        catch {
            //TODO: Apply synchronize
            // self.synchronize()
            return nil
        }

        if !(self.isAtEnd) {
            _ = self.reportParseError(message: "Excess tokens in input")
        }

        return expr

    }

    //MARK:- Grammar rules

    private func expression() throws -> Expr
    {
        return try self.equality()
    }

    private func equality() throws -> Expr
    {
        var expr = try self.comparison()

        while self.matchAny(.bangEqual, .equalEqual) {
            let op = self.previous
            let right = try self.comparison()
            expr = Binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func comparison() throws -> Expr
    {
        var expr = try self.addition()

        while self.matchAny(.greater, .greaterEqual, .less, .lessEqual) {
            let op = self.previous
            let right = try self.addition()
            expr = Binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func addition() throws -> Expr
    {
        var expr = try self.multiplication()

        while self.matchAny(.minus, .plus) {
            let op = self.previous
            let right = try self.multiplication()
            expr = Binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func multiplication() throws -> Expr
    {
        var expr = try self.unary()

        while self.matchAny(.slash, .star) {
            let op = self.previous
            let right = try self.unary()
            expr = Binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func unary() throws -> Expr
    {
        guard self.matchAny(.bang, .minus) else {
            return try self.primary()
        }

        let op = self.previous
        let right = try self.unary()
        return Unary(op: op, expr: right)
    }

    private func primary() throws -> Expr
    {
        if self.matchAny(.false) { return Literal(value: .bool(false)) }
        if self.matchAny(.true) { return Literal(value: .bool(true)) }
        if self.matchAny(.nil) { return Literal(value: .nil) }

        if self.matchAny(.number, .string) {
            return Literal(value: self.previous.literal!)
        }

        if self.matchAny(.leftParen) {
            let expr = try self.expression()
            try self.mustConsume(.rightParen,
                                 message: "Expected ')' to match earlier '('")
            self.matchBadToken(.rightParen)
            return Grouping(expr: expr)
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

    /** Check for an error production; consume and report it if found */
    private func matchBadToken(_ kind: Token.Kind)
    {
        guard !(self.isAtEnd) else { return }
        if self.matchAny(kind) {
            _ = self.reportParseError(message: "Misplaced \(kind) token")
        }
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

    private func synchronize()
    {
        self.advanceIndex()

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

