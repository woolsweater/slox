import Foundation

class Interpreter : ExpressionReader
{
    func interpret(_ expression: Expression) {
        guard let value = self.read(expression) else {
            print("Unable to interpret")
            return
        }

        print(value)
    }

    func read(_ expression: Expression) -> Any?
    {
        switch expression {
            case let .literal(value):
                return self.interpretLiteral(value)
            case let .unary(op: opToken, operand):
                return self.interpretUnary(op: opToken, operand)
            case let .binary(left: left, op: opToken, right: right):
                return self.interpretBinary(leftExpr: left, op: opToken, rightExpr: right)
            case let .grouping(groupedExpression):
                return self.read(groupedExpression)
        }
    }

    private func interpretLiteral(_ value: LiteralValue) -> Any?
    {
        switch value {
            case let .double(double): return double
            case let .string(string): return string
            case let .bool(bool): return bool
            case .nil: return nil
        }
    }

    private func interpretUnary(op: Token, _ expression: Expression) -> Any?
    {
        let operandValue = self.read(expression)

        switch op.kind {
            case .minus:
                return -self.doubleValue(of: operandValue)
            case .bang:
                return !self.truthValue(of: operandValue)
            default:
                //TODO: Handle bad operator
                return nil
        }
    }

    private func doubleValue(of value: Any?) -> Double
    {
        //TODO: Handle error
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

    private func interpretBinary(leftExpr: Expression, op: Token, rightExpr: Expression) -> Any?
    {
        let leftValue = self.read(leftExpr)
        let rightValue = self.read(rightExpr)

        switch op.kind {
            case .minus:
                return self.performArithmetic(using: (-), leftValue, rightValue)
            case .slash:
                return self.performArithmetic(using: (/), leftValue, rightValue)
            case .star:
                return self.performArithmetic(using: (*), leftValue, rightValue)
            case .plus:
                if leftValue is Double && rightValue is Double {
                    return self.performArithmetic(using: (+), leftValue, rightValue)
                }
                else if let leftString = leftValue as? String, let rightString = rightValue as? String {
                    return leftString + rightString
                }
                else {
                    //TODO: Handle bad operands
                    return nil
                }
            case .greater:
                return self.compareNumbers(using: (>), leftValue, rightValue)
            case .greaterEqual:
                return self.compareNumbers(using: (>=), leftValue, rightValue)
            case .less:
                return self.compareNumbers(using: (<), leftValue, rightValue)
            case .lessEqual:
                return self.compareNumbers(using: (<=), leftValue, rightValue)
            case .equalEqual:
                return self.areEqual(leftValue, rightValue)
            case .bangEqual:
                return !(self.areEqual(leftValue, rightValue))
            default:
                //TODO: Handle bad operator
                return nil
        }
    }

    private func performArithmetic(using op: (Double, Double) -> Double, _ left: Any?, _ right: Any?) -> Double
    {
        return op(self.doubleValue(of: left), self.doubleValue(of: right))
    }

    private func compareNumbers(using op: (Double, Double) -> Bool, _ left: Any?, _ right: Any?) -> Bool
    {
        return op(self.doubleValue(of: left), self.doubleValue(of: right))
    }

    private func areEqual(_ left: Any?, _ right: Any?) -> Bool
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
}
