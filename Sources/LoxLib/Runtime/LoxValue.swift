import Foundation

/**
 A value in the Lox runtime. Wraps the corresponding
 Swift value.
 */
enum LoxValue : Equatable
{
    /** A numeric value */
    case double(Double)
    /** A string value */
    case string(String)
    /** A boolean value */
    case bool(Bool)
    /** A value that can be invoked like a function. */
    case callable(Callable)
    /**
     The absence of any other value.
     - remark: This is distinct from an *uninitialized*
     state. Lox `nil` is an actual, legal value. It is an error
     for user code to try to read a variable that has never had
     a value assigned.
     */
    case `nil`
}

extension LiteralValue
{
    /**
     Convert the literal to its corresponding value in the Lox runtime.
     */
    var loxValue: LoxValue
    {
        switch self {
            case let .double(double): return .double(double)
            case let .string(string): return .string(string)
            case let .bool(bool): return .bool(bool)
            case .nil: return .nil
        }
    }
}
