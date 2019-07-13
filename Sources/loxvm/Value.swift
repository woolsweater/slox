/** A Lox runtime value, wrapping the appropriate host value. */
enum Value
{
    case bool(Bool)
    case `nil`
    case number(Double)
}

extension Value
{
    /**
     The value interpreted as a boolean: `nil` and `false` are "falsey"; everything
     else is "truthy".
     */
    var isFalsey: Bool
    {
        switch self {
            case .nil:
                return true
            case let .bool(boolean):
                return !boolean
            default:
                return false
        }
    }
}

extension Value : Equatable
{
    static func == (lhs: Value, rhs: Value) -> Bool
    {
        switch (lhs, rhs) {
            case let (.bool(left), .bool(right)):
                return left == right
            case let (.number(left), .number(right)):
                return left == right
            case (.nil, .nil):
                return true
            default:
                return false
        }
    }
}
