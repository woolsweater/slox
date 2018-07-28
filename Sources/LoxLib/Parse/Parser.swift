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

    func parse() -> Expression?
    {
        let expr: Expression

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

    private func expression() throws -> Expression
    {
        return try self.joined()
    }

    private func joined() throws -> Expression
    {
        if self.matchAny(.comma) {
            _ = self.reportParseError(message: "missing lefthand expression")
            return try self.joined()
        }

        var expr = try self.equality()

        while self.matchAny(.comma) {
            let op = self.previous
            let right = try self.equality()
            expr = .binary(left: expr, op: op, right: right)
        }

        return expr
    }

    private func equality() throws -> Expression
    {
        if self.matchAny(.bangEqual, .equalEqual) {
            _ = self.reportParseError(message: "missing lefthand expression")
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
            _ = self.reportParseError(message: "missing lefthand expression")
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
            _ = self.reportParseError(message: "missing lefthand expression")
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

