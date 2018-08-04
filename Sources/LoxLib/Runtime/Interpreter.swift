import Foundation

class Interpreter
{
    /**
     Variable/value pairs in the current scope. Changes as blocks are entered
     and exited.
     */
    private var environment = Environment()

    /**
     Whether the interpreter is running in a REPL instead of interpreting a
     file. In the REPL case, the evaluated result of each expression statement
     will be printed and also stored in a special "cut" variable.
     */
    private let isRepl: Bool

    init(replMode: Bool)
    {
        self.isRepl = replMode
        if self.isRepl {
            self.environment.createCut()
        }
    }

    func interpret(_ program: [Statement]) {
        do {
            for statement in program {
                try self.execute(statement)
            }
        }
        catch let error as RuntimeError {
            self.reportRuntimeError(error)
        }
        catch {
            fatalError("Unknown interpretation failure")
        }
    }

    private func execute(_ statement: Statement) throws
    {
        switch statement {
            case let .variableDecl(name: name, initializer: expression):
                try self.evaluateVariableDecl(name: name, initializer: expression)
            case let .expression(expression):
                let value = try self.evaluate(expression)
                if self.isRepl {
                    print(self.stringify(value))
                    try self.environment.updateCut(value: value)
                }
            case let .conditional(condition, then: thenBranch, else: elseBranch):
                try self.executeConditional(condition,
                                            thenBranch: thenBranch,
                                            elseBranch: elseBranch)
            case let .print(expression):
                let value = try self.evaluate(expression)
                print(self.stringify(value))
            case let .loop(condition: condition, body: body):
                try self.executeLoop(condition: condition, body: body)
            case .breakLoop:
                throw BreakLoop()
            case let .block(statements):
                try self.executeBlock(statements)
        }
    }

    private func evaluate(_ expression: Expression) throws -> LoxValue
    {
        switch expression {
            case let .literal(literal):
                return literal.loxValue
            case let .grouping(groupedExpression):
                return try self.evaluate(groupedExpression)
            case let .variable(name):
                return try self.environment.read(variable: name)
            case let .unary(op: opToken, operand):
                return try self.evaluateUnary(op: opToken, operand)
            case let .binary(left: left, op: opToken, right: right):
                return try self.evaluateBinary(leftExpr: left,
                                                      op: opToken,
                                               rightExpr: right)
            case let .assignment(name: name, value: value):
                return try self.evaluateAssignment(name: name, value: value)
            case let .logical(left: left, op: op, right: right):
                return try self.evaluateLogical(leftExpr: left, op: op, rightExpr: right)
        }
    }

    //MARK:- Variables

    private func evaluateVariableDecl(name: Token, initializer: Expression?) throws
    {
        let value = try initializer.flatMap(self.evaluate)
        self.environment.define(name: name.lexeme, value: value)
    }

    private func evaluateAssignment(name: Token, value: Expression) throws -> LoxValue
    {
        let evaluated = try self.evaluate(value)
        try self.environment.assign(variable: name, value: evaluated)

        return evaluated
    }

    //MARK:- Conditional

    private func executeConditional(_ condition: Expression, thenBranch: Statement, elseBranch: Statement?) throws
    {
        let conditionValue = try self.evaluate(condition)
        if self.truthValue(of: conditionValue) {
            try self.execute(thenBranch)
        }
        else {
            try elseBranch.flatMap(self.execute)
        }
    }

    //MARK:- Loop

    private func executeLoop(condition: Expression, body: Statement) throws
    {
        do {
            while try self.truthValue(of: self.evaluate(condition)) {
                try self.execute(body)
            }
        }
        catch is BreakLoop {
            return
        }
        catch {
            throw error
        }
    }

    //MARK:- Blocks

    private func executeBlock(_ statements: [Statement]) throws
    {
        self.environment = Environment(nestedIn: self.environment)
        defer { self.environment = self.environment.enclosing! }

        for statement in statements {
            try self.execute(statement)
        }
    }

    //MARK:- Unary

    private func evaluateUnary(op: Token, _ expression: Expression) throws -> LoxValue
    {
        let operandValue = try self.evaluate(expression)

        switch op.kind {
            case .minus:
                guard case let .double(doubleValue) = operandValue else {
                    throw RuntimeError.numeric(at: op)
                }
                return .double(-doubleValue)
            case .bang:
                return .bool(!self.truthValue(of: operandValue))
            default:
                fatalError("Found invalid unary operator \(op.kind)")
        }
    }

    //MARK:- Binary

    private func evaluateBinary(leftExpr: Expression, op: Token, rightExpr: Expression) throws -> LoxValue
    {
        let leftValue = try self.evaluate(leftExpr)
        let rightValue = try self.evaluate(rightExpr)

        switch op.kind {
            case .minus: fallthrough
            case .slash: fallthrough
            case .star:
                guard case let .double(lhs) = leftValue, case let .double(rhs) = rightValue else {
                    throw RuntimeError.numeric(at: op)
                }
                let arithmeticOperation = op.arithmeticOperation!
                return .double(arithmeticOperation(lhs, rhs))
            case .plus:
                if case let .double(lhs) = leftValue, case let .double(rhs) = rightValue {
                    let arithmeticOperation = op.arithmeticOperation!
                    return .double(arithmeticOperation(lhs, rhs))
                }
                else if case let .string(lhs) = leftValue, case let .string(rhs) = rightValue {
                    return .string(lhs + rhs)
                }
                else {
                    throw RuntimeError(token: op,
                                     message: "Operands must be string or number with matching types")
                }
            case .greater: fallthrough
            case .greaterEqual: fallthrough
            case .less: fallthrough
            case .lessEqual:
                guard case let .double(lhs) = leftValue, case let .double(rhs) = rightValue else {
                    throw RuntimeError.numeric(at: op)
                }
                let comparisonOperation = op.comparisonOperation!
                return .bool(comparisonOperation(lhs, rhs))
            case .equalEqual:
                return .bool(leftValue == rightValue)
            case .bangEqual:
                return .bool(leftValue != rightValue)
            case .comma:
                return rightValue
            default:
                fatalError("Found invalid binary operator '\(op.kind)'")
        }
    }

    //MARK:- Logical binary

    private func evaluateLogical(leftExpr: Expression, op: Token, rightExpr: Expression) throws -> LoxValue
    {
        let leftValue = try self.evaluate(leftExpr)
        let isLeftTrue = self.truthValue(of: leftValue)

        switch op.kind {
            case .or:
                if isLeftTrue { return leftValue }
            case .and:
                if !(isLeftTrue) { return leftValue }
            default:
                fatalError("Found non-logical operator '\(op.kind)' in logical expression")
        }

        return try self.evaluate(rightExpr)
    }

    //MARK:- Helper

    private func truthValue(of value: LoxValue) -> Bool
    {
        switch value {
            case let .bool(boolValue):
                return boolValue
            case .nil:
                return false
            default:
                return true
        }
    }

    private func stringify(_ value: LoxValue) -> String
    {
        switch value {
            case let .double(double):
                return self.formatNumber(double)
            case let .string(string):
                return string
            case let .bool(bool):
                return String(describing: bool)
            case .nil:
                return "nil"
        }
    }

    private func formatNumber(_ number: Double) -> String {
        if number.isIntegral {
            return String(Int(number))
        } else {
            return String(number)
        }
    }

    //MARK:- Error handling

    private func reportRuntimeError(_ error: RuntimeError)
    {
        let token = error.token
        let locationDescription = token.kind == .EOF ? "end" : "'\(token.lexeme)'"
        Lox.report(at: token.line,
             location: "at \(locationDescription)",
              message: error.message)
    }
}

private extension RuntimeError
{
    static func numeric(at token: Token) -> RuntimeError
    {
        return RuntimeError(token: token, message: "Operand must be a number")
    }
}

private extension Double
{
    var isIntegral: Bool { return 0 == self.truncatingRemainder(dividingBy: 1) }
}
