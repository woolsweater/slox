import Foundation

/**
 Descriptor for a function during processing. Used by both the
 parser and static analysis to check for errors.
 */
enum FuncKind : String, Equatable
{
    /** A free function. */
    case function

    /** A method on a class. */
    case method

    /**
     A getter on a class; this is a function that takes no parameters and must return a value.
     */
    case getter

    /** An initializer method on a class. */
    case initializer
}

extension FuncKind : CustomStringConvertible
{
    /** User-facing description of this function kind. */
    var description: String { return self.rawValue }
}
