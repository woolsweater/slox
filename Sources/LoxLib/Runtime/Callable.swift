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

    private let thunk: CallableInvocation

    init(name: String, arity: Int, thunk: @escaping CallableInvocation)
    {
        self.name = name
        self.arity = arity
        self.thunk = thunk
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
     - parameter parameters: The list of identifier tokens for the function's parameters.
     May be empty.
     - parameter body: The list of statements contained in the function.
     - parameter environment: The active environment at the time of declaration; this
     allows the function to capture variables from its surrounding scope.
     */
    static func fromDecl(name: String,
                   parameters: [Token],
                         body: [Statement],
                  environment: Environment)
        -> Callable
    {
        return Callable(name: name, arity: parameters.count) {
            (interpreter, arguments) in
            let innerEnvironment = Environment(nestedIn: environment)
            for (parameter, argument) in zip(parameters, arguments) {
                innerEnvironment.define(name: parameter.lexeme, value: argument)
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
