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
                return ObjectRef.debugDescription(of: obj)
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

    /** Whether this value wraps an object of the given type */
    func isObject(kind: ObjectKind) -> Bool
    {
        return self.object?.pointee.kind == kind
    }

    /** If this value is an object, the wrapped `ObjectRef`, else `nil` */
    var object: ObjectRef?
    {
        guard case let .object(obj) = self else {
            return nil
        }
        return obj
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
    /**
     Determine the subtype of the given objects and compare their payloads as
     appropriate.
     */
    static func equalObjects(_ lhs: ObjectRef, _ rhs: ObjectRef) -> Bool
    {
        switch (lhs.pointee.kind, rhs.pointee.kind) {
            case (.string, .string):
                let left = lhs.asStringRef()
                let right = rhs.asStringRef()
                return left.pointee.length == right.pointee.length &&
                    0 == memcmp(left.chars, right.chars, left.pointee.length)
            default:
                return false
        }
    }

    /**
     Determine the subtype of the given object and produce an appropriate
     debug string representation.
     */
    static func debugDescription(of object: ObjectRef) -> String
    {
        switch object.pointee.kind {
            case .string:
                let contents = String(cString: object.asStringRef().chars)
                return "String(\(contents))"
        }
    }
}
