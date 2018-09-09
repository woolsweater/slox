import Foundation

/** Runtime representation of an instance of a Lox class. */
class LoxInstance
{
    /** The Lox class of which this is an instance. */
    private let klass: LoxClass

    /**
     Values that have been stored on this instance by name.
     - remark: Since properties are freely addable to instances,
     two instances of the same class are not guaranteed to have
     the same properties, except where the class has a declared
     initializer.
     */
    private var fields: [String : LoxValue] = [:]

    /** Create an instance of the given `LoxClass`. */
    init(klass: LoxClass)
    {
        self.klass = klass
    }

    /**
     Access a member by name.
     - throws: A `RuntimeError` if the name has not been assigned a
     value on this instance (as either a property or a method).
     - returns: The result of looking up the name in this instance's
     stored values.
     */
    func get(_ member: Token) throws -> LoxValue
    {
        let name = member.lexeme
        if let value = self.fields[name] {
            return value
        }
        else if let method = self.klass.instanceMethod(named: name) {
            let bound = method.boundTo(object: self)
            return .callable(bound)
        }
        else {
            throw RuntimeError.unrecognizedMember(member)
        }
    }

    /**
     Assign the given value to the named property on this instance.
     - note: Properties may be freely assigned; the name does not
     need to already exist on the instance.
     */
    func set(_ member: Token, to value: LoxValue)
    {
        self.fields[member.lexeme] = value
    }
}

extension LoxInstance : Equatable
{
    /** Equality for `LoxInstance`s is based on object identity. */
    static func == (lhs: LoxInstance, rhs: LoxInstance) -> Bool
    {
        return lhs === rhs
    }
}

extension LoxInstance : CustomStringConvertible
{
    var description: String { return "instanceof \(self.klass)" }
}
