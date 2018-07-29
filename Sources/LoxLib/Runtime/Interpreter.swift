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
            case let .print(expression):
                let value = try self.evaluate(expression)
                print(self.stringify(value))
            case let .expression(expression):
                let value = try self.evaluate(expression)
                if self.isRepl {
                    print(self.stringify(value))
                    try self.environment.updateCut(value: value)
                }
            case let .variableDecl(name: name, initializer: expression):
                try self.evaluateVariableDecl(name: name, initializer: expression)
            case let .block(statements):
                try self.executeBlock(statements)
        }
    }

    private func evaluate(_ expression: Expression) throws -> Any?
    {
        switch expression {
            case let .literal(value):
                return self.interpretLiteral(value)
            case let .grouping(groupedExpression):
                return try self.evaluate(groupedExpression)
            case let .variable(name):
                return try self.environment.read(variable: name)
            case let .unary(op: opToken, operand):
                return try self.interpretUnary(op: opToken, operand)
            case let .binary(left: left, op: opToken, right: right):
                return try self.interpretBinary(leftExpr: left,
                                                      op: opToken,
                                               rightExpr: right)
            case let .assignment(name: name, value: value):
                return try self.evaluateAssignment(name: name, value: value)
        }
    }

    //MARK:- Literal

    private func interpretLiteral(_ value: LiteralValue) -> Any?
    {
        switch value {
            case let .double(double): return double
            case let .string(string): return string
            case let .bool(bool): return bool
            case .nil: return nil
        }
    }

    //MARK:- Variables

    private func evaluateVariableDecl(name: Token, initializer: Expression?) throws
    {
        let value = try initializer.flatMap(self.evaluate)
        self.environment.define(name: name.lexeme, value: value)
    }

    private func evaluateAssignment(name: Token, value: Expression) throws -> Any?
    {
        let evaluated = try self.evaluate(value)
        try self.environment.assign(variable: name, value: evaluated)

        return evaluated
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

    private func interpretUnary(op: Token, _ expression: Expression) throws -> Any?
    {
        let operandValue = try self.evaluate(expression)

        switch op.kind {
            case .minus:
                guard let doubleValue = operandValue as? Double else {
                    throw RuntimeError.numeric(at: op)
                }
                return -doubleValue
            case .bang:
                return !self.truthValue(of: operandValue)
            default:
                fatalError("Found invalid unary operator \(op.kind)")
        }
    }

    private func interpretBinary(leftExpr: Expression, op: Token, rightExpr: Expression) throws -> Any?
    {
        let leftValue = try self.evaluate(leftExpr)
        let rightValue = try self.evaluate(rightExpr)

        switch op.kind {
            case .minus: fallthrough
            case .slash: fallthrough
            case .star:
                return try self.performArithmetic(for: op, leftValue, rightValue)
            case .plus:
                if leftValue is Double && rightValue is Double {
                    return try! self.performArithmetic(for: op, leftValue, rightValue)
                }
                else if let leftString = leftValue as? String, let rightString = rightValue as? String {
                    return leftString + rightString
                }
                else {
                    throw RuntimeError(token: op,
                                     message: "Operands must be string or number with matching types")
                }
            case .greater: fallthrough
            case .greaterEqual: fallthrough
            case .less: fallthrough
            case .lessEqual:
                return try self.compareNumbers(using: op, leftValue, rightValue)
            case .equalEqual:
                return self.evaluateEquality(leftValue, rightValue)
            case .bangEqual:
                return !(self.evaluateEquality(leftValue, rightValue))
            case .comma:
                return rightValue
            default:
                fatalError("Found invalid binary operator \(op.kind)")
        }
    }

    //MARK:- Helper

    private func doubleValue(of value: Any?) -> Double
    {
        return value as! Double
    }

    private func truthValue(of value: Any?) -> Bool
    {
        if let boolValue = value as? Bool {
            return boolValue
        } else if value == nil {
            return false
        } else {
            return true
        }
    }

    private func performArithmetic(for token: Token, _ left: Any?, _ right: Any?) throws -> Double
    {
        let operation = token.kind.arithmeticOperation!
        guard let leftDouble = left as? Double, let rightDouble = right as? Double else {
            throw RuntimeError.numeric(at: token)
        }
        return operation(leftDouble, rightDouble)
    }

    private func compareNumbers(using token: Token, _ left: Any?, _ right: Any?) throws -> Bool
    {
        let operation = token.kind.comparisonOperation!
        guard let leftDouble = left as? Double, let rightDouble = right as? Double else {
            throw RuntimeError.numeric(at: token)
        }
        return operation(leftDouble, rightDouble)
    }

    private func evaluateEquality(_ left: Any?, _ right: Any?) -> Bool
    {
        if let leftDouble = left as? Double, let rightDouble = right as? Double {
            return leftDouble == rightDouble
        }
        else if let leftString = left as? String, let rightString = right as? String {
            return leftString == rightString
        }
        else if let leftBool = left as? Bool, let rightBool = right as? Bool {
            return leftBool == rightBool
        }
        else if left == nil && right == nil {
            return true
        }
        else {
            return false
        }
    }

    private func stringify(_ value: Any?) -> String
    {
        guard let value = value else {
            return "nil"
        }

        if let doubleValue = value as? Double {
            if doubleValue.isIntegral {
                return String(Int(doubleValue))
            } else {
                return String(doubleValue)
            }
        }

        return String(describing: value)
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
