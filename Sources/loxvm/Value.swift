import loxvm_object

/** A Lox runtime value, wrapping the appropriate host value. */
enum Value
{
    case bool(Bool)
    case `nil`
    case number(Double)
    case object(ObjectRef)
}

extension Value : CustomDebugStringConvertible
{
    var debugDescription: String
    {
        switch self {
            case let .bool(value): return "bool(\(value))"
            case .nil: return "nil"
            case let .number(value): return "number(\(value))"
            case let .object(obj):
                switch obj.pointee.kind {
                    case .string:
                        let contents = String(cString: obj.asStringRef().pointee.chars)
                        return "String(\(contents))"
            }
        }
    }
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
            case let (.object(left), .object(right)):
                return ObjectRef.equalObjects(left, right)
            default:
                return false
        }
    }
}

extension ObjectRef
{
    static func equalObjects(_ lhs: ObjectRef, _ rhs: ObjectRef) -> Bool
    {
        switch (lhs.pointee.kind, rhs.pointee.kind) {
            case (.string, .string):
                let left = lhs.asStringRef().pointee
                let right = rhs.asStringRef().pointee
                return left.length == right.length &&
                    memcmp(left.chars, right.chars, left.length) == 0
            default:
                return false
        }
    }
}
