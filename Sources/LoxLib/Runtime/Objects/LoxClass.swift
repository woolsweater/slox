import Foundation

/** Runtime representation of a class in a Lox program. */
class LoxClass
{
    /** The class's identifier in the interpreted source. */
    let name: String

    /**
     The initializer, if any, for this class.
     - remark: Stored separately from other methods because it can only be
     called via the class name.
     */
    private let initializer: Callable?

    /** Instance methods declared on this class. */
    private let methods: [String : Callable]

    /** Create a class with the given name and method list. */
    init(name: String, methods: [String : Callable])
    {
        self.name = name
        var regularMethods = methods
        self.initializer =
            regularMethods.removeValue(forKey: LoxClass.initializerName)
        self.methods = regularMethods
    }

    /**
     Create an instance of this class, calling the initializer if one has been
     declared.
     - parameter interpreter: The interpreter, passed in for access to the current
     environment.
     - parameter location: The token for the closing parenthesis of the call
     expression, used for error reporting.
     - parameter arguments: Arguments that were present at the call site; these
     will be passed on to the initializer.
     - throws: An arity error if either a) the class has no declared initializer and
     `arguments` is not empty or b) the declared initializer's arity does not match
     the count of `arguments`.
     - returns: The created and initialized `LoxInstance`.
     */
    func allocInit(using interpreter: Interpreter,
                            at paren: Token,
                           arguments: [LoxValue])
        throws -> LoxInstance
    {
        let instance = LoxInstance(klass: self)
        if let initializer = self.initializer?.boundTo(object: instance) {
            // The instance is configured by mutation; return value is irrelevant
            _ = try initializer.invoke(using: interpreter, at: paren, arguments: arguments)
        }
        return instance
    }

    /**
     Look up a the given name in the class's instance method table, returning
     the corresponding `Callable` if present.
     */
    func instanceMethod(named name: String) -> Callable?
    {
        return self.methods[name]
    }
}

extension LoxClass
{
    /** The special name for a Lox method that is run at instance creation. */
    static let initializerName = "init"
}

extension LoxClass : Equatable
{
    /** Equality for `LoxClass`es is based on object identity. */
    static func == (lhs: LoxClass, rhs: LoxClass) -> Bool
    {
        return lhs === rhs
    }
}

extension LoxClass : CustomStringConvertible
{
    var description: String { return self.name }
}
