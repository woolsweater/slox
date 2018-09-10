import Foundation

typealias CallableInvocation = (Interpreter, [LoxValue]) throws -> LoxValue

/** A Lox value that can be the target of a call expression. */
final class Callable : Equatable, CustomStringConvertible
{
    var description: String { return "<fn \(self.name)(@\(self.arity))>" }

    /** The number of arguments required when invoking. */
    let arity: Int

    /** The name of this function. */
    let name: String

    /**
     If `true`, the value should be invoked when accessed, without requiring
     an explicit call.
     */
    let isImplicitlyInvoked: Bool

    /**
     If this is a method, `boundObject` is the object from which the
     method was accessed. It will be provided as a hidden argument at
     invocation.
     */
    private let boundObject: LoxInstance?

    private let thunk: CallableInvocation

    init(name: String, implicitlyInvoked: Bool = false, arity: Int, thunk: @escaping CallableInvocation)
    {
        self.name = name
        self.isImplicitlyInvoked = implicitlyInvoked
        self.arity = arity
        self.thunk = thunk
        self.boundObject = nil
    }

    private init(other: Callable, boundObject: LoxInstance)
    {
        self.name = other.name
        self.isImplicitlyInvoked = other.isImplicitlyInvoked
        self.arity = other.arity
        self.thunk = other.thunk
        self.boundObject = boundObject
    }

    /**
     Associate the given object with this method so that it can be accessed
     within the method body.
     */
    func boundTo(object: LoxInstance) -> Callable
    {
        return Callable(other: self, boundObject: object)
    }

    /**
     Execute the code represented by this value.
     - remark: The interpreter is passed in for access to the environment.
     */
    func invoke(using interpreter: Interpreter,
                at parameterToken: Token,
                        arguments: [LoxValue])
        throws -> LoxValue
    {
        var arguments = arguments
        if let object = self.boundObject {
            arguments.insert(.instance(object), at: 0)
        }

        guard arguments.count == self.arity else {
            throw RuntimeError.arityMismatch(at: parameterToken,
                                          arity: self.arity,
                                       argCount: arguments.count)
        }
        return try self.thunk(interpreter, arguments)
    }
}

extension Callable
{
    /** Equality for two `Callable`s is based on object identity. */
    static func == (lhs: Callable, rhs: Callable) -> Bool
    {
        return lhs === rhs
    }
}

extension Callable
{
    /**
     Create an invokable object from an unpacked `Statement.functionDecl`.
     - remark: In other words, this creates the runtime representation of a function
     defined in the user's source code.
     - parameter name: The identifier for the function.
     - parameter kind: The kind of function declaration. A `.getter` will produce a `Callable`
     with the `isImplicitlyInvoked` flag set.
     - parameter parameters: The list of identifier tokens for the function's parameters.
     May be empty.
     - parameter body: The list of statements contained in the function.
     - parameter environment: The active environment at the time of declaration; this
     allows the function to capture variables from its surrounding scope.
     */
    static func fromDecl(name: String,
                         kind: FuncKind,
                   parameters: [Token],
                         body: [Statement],
                  environment: Environment)
        -> Callable
    {
        let isGetter = (kind == .getter)
        return Callable(name: name, implicitlyInvoked: isGetter, arity: parameters.count) {
            (interpreter, arguments) in
            let innerEnvironment = Environment(nestedIn: environment)
            for argument in arguments {
                innerEnvironment.define(value: argument)
            }

            do { try interpreter.executeBlock(body, environment: innerEnvironment) }
            catch let returnValue as Return {
                return returnValue.value
            }
            catch {
                throw error
            }
            return .nil
        }
    }
}
