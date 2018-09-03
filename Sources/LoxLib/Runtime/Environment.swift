import Foundation

/**
 Runtime environment for an `Interpreter`. Keeps a record of values in
 the current scope, and a reference to the next outer scope. The values
 are looked up by index, first by walking to the correct enclosing
 environment, then the position within that.
 */
class Environment
{
    /**
     The scope that existed just before this one became active. If a
     lookup fails in the current scope, it is retried recursively
     outwards, via this reference.
     */
    let enclosing : Environment?

    /** The collection of values defined in this scope. */
    private var values : [LoxValue?] = []

    /** Create an environment nested inside the given one. */
    init(nestedIn: Environment? = nil)
    {
        self.enclosing = nestedIn
    }

    /** Add the given value to the environment. */
    func define(value: LoxValue?)
    {
        self.values.append(value)
    }

    /**
     Look up the value of the given variable, walking back `distance`
     environments and then producing the value at `index` within that
     environment.
     - parameter variable: The `Token` representing the variable, for
     error reporting.
     - parameter distance: The number of environments between this and
     the one containing the sought value, as determined by static
     analysis.
     - parameter index: The position of the sought value in the correct
     environment's list, as determined by static analysis.
     - throws: A `RuntimeError` if the variable is not visible in any
     reachable scope, or if it was declared but never assigned a value.
     - returns: The value of the variable.
     */
    func read(variable: Token, at distance: Int, index: Int) throws -> LoxValue
    {
        precondition(distance >= 0)
        precondition(index >= 0)

        guard
            let ancestor = self.ancestor(at: distance),
            ancestor.values.count > index else
        {
            throw RuntimeError.undefined(variable)
        }

        guard let value = ancestor.values[index] else {
            throw RuntimeError.uninitialized(variable)
        }

        return value
    }

    /**
     Bind the variable at the given indexes to the new value. The variable must exist
     in one of the scope reachable from this one.
     - throws: A `RuntimeError` if the (`distance`, `index`) pair does not lead to
     an existing slot in a reachable scope. This means that the variable is not
     defined.
     */
    func assign(variable: Token, value: LoxValue, distance: Int, index: Int) throws
    {
        precondition(distance >= 0)
        precondition(index >= 0)

        guard
            let ancestor = self.ancestor(at: distance),
            ancestor.values.count > index else
        {
            throw RuntimeError.undefined(variable)
        }

        ancestor.values[index] = value
    }

    //MARK:- Internal

    /**
     Walk back through `enclosing` environments by `distance` steps.
     - returns: `nil` if `distance` is greater than the number of
     reachable environments, or the resulting `Environment`.
     */
    private func ancestor(at distance: Int) -> Environment?
    {
        var ancestor: Environment? = self
        for _ in 0..<distance {
            ancestor = ancestor?.enclosing
        }

        return ancestor
    }
}
