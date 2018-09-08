import Foundation

/** Runtime representation of a class in a Lox program. */
class LoxClass
{
    let name: String

    /** Create a class with the given name. */
    init(name: String)
    {
        self.name = name
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
