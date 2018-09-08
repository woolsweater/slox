import Foundation

/** Runtime representation of a class in a Lox program. */
class LoxClass
{
    /** The class's identifier in the interpreted source. */
    let name: String

    /** Instance methods declared on this class. */
    private let methods: [String : Callable]

    /** Create a class with the given name and method list. */
    init(name: String, methods: [String : Callable])
    {
        self.name = name
        self.methods = methods
    }

    /**
     Create an instance of this class, calling the initializer if one has been
     declared.
     - parameter interpreter: The interpreter, passed in for access to the current
     environment.
     - parameter arguments: Arguments that were present at the call site; these
     will be passed on to the initializer.
     - throws: An arity error if either a) the class has no declared initializer and
     `arguments` is not empty or b) the declared initializer's arity does not match
     the count of `arguments`.
     - returns: The created and initialized `LoxInstance`
     */
    func allocInit(using interpreter: Interpreter, arguments: [LoxValue]) throws -> LoxInstance
    {
        let instance = LoxInstance(klass: self)
        //TODO: Use initializer if present
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
