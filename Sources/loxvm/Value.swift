import loxvm_object

/** A Lox runtime value, wrapping the appropriate host value. */
enum Value
{
    case bool(Bool)
    case `nil`
    case number(Double)
    case object(ObjectRef)
}

extension Value
{
    /**
     Convenience for creating a `Value.number` from an integer instead of a `Double`.
     */
    static func number<I : FixedWidthInteger>(_ integer: I) -> Value
    {
        return .number(Double(integer))
    }

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

    /**
     The value interpreted as a boolean: `nil` and `false` are "falsey"; everything
     else is "truthy".
     */
    var isTruthy: Bool { !self.isFalsey }

    /** If this value is a number, the wrapped value as an integer; else `nil`. */
    var asInt: Int?
    {
        guard case let .number(n) = self else {
            return nil
        }
        return Int(n)
    }

    /** If this value is an object, the wrapped `ObjectRef`, else `nil` */
    var object: ObjectRef?
    {
        guard case let .object(obj) = self else {
            return nil
        }
        return obj
    }

    /** Whether this value wraps an object of the given type */
    func isObject(kind: ObjectKind) -> Bool
    {
        return self.object?.pointee.kind == kind
    }

    func formatted() -> String
    {
        switch self {
            case let .bool(value):
                return "\(value)"
            case .nil:
                return "nil"
            case let .number(value):
                return String(format: "%g", value)
            case let .object(obj):
                return ObjectRef.format(obj)
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

/** Operations on objects that are relevant in a `Value` wrapper context. */
extension ObjectRef
{
    /**
     Determine the subtype of the given objects and compare their payloads as
     appropriate.
     */
    static func equalObjects(_ lhs: ObjectRef, _ rhs: ObjectRef) -> Bool
    {
        switch (lhs.pointee.kind, rhs.pointee.kind) {
            case (.string, .string):
                // All strings are uniqued and interned by the Compiler
                return lhs == rhs
            default:
                return false
        }
    }

    /**
     Determine the subtype of the given object and produce an appropriate
     user-facing string representation.
     */
    static func format(_ object: ObjectRef) -> String
    {
        switch object.pointee.kind {
            case .string:
                return String(cString: object.asStringRef().chars)
        }
    }
}
