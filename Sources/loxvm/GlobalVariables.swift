import Foundation
import loxvm_object

/**
 Storage for global variables in an interpretation context.

 At compile time, variable names are mapped to storage indexes; at runtime the
 values are accessed only by the index.
 */
class GlobalVariables
{
    /**
     Mapping of each variable name to the index in `values` where its value is
     stored.
     - remark: Primarily for use at compile-time; at runtime it is only relevant
     for errors/debugging.
     */
    private let names: HashTable

    /**
     The actual storage for the variables' values. Each slot `i` in the array
     corresponds to the key in `names` where the value is `i`.

     Each value will be `Swift.nil`, and trying to access the variable will be
     an error, until the variable's declaration statement is executed.
     */
    private var values: [Value?]    //TODO: This should be managed by Lox

    init(allocator: MemoryManager)
    {
        self.names = HashTable(manager: allocator)
        self.values = []
    }
}

//MARK:- Compile time
extension GlobalVariables
{
    /**
     Look up the index of the given name. If it is unknown, add new storage
     for `name`, and return the new index.
     */
    func index(for name: StringRef) -> Int
    {
        if let existing = self.names.value(for: name)?.asInt {
            return existing
        }
        else {
            return self.createStorage(for: name)
        }
    }

    /**
     Add `name` to the set of known globals, with an empty value.
     - returns: The index of the new variable's storage.
     */
    private func createStorage(for name: StringRef) -> Int
    {
        let index = self.values.count
        self.names.insert(.number(index), for: name)
        self.values.append(nil)
        return index
    }
}

//MARK:- Runtime
extension GlobalVariables
{
    /**
     Mark the global storage at `index` as having been declared, by storing
     `value` there.
     */
    func initialize(_ index: Int, with value: Value)
    {
        guard self.values.indices ~= index else {
            fatalError("Internal error: Invalid global slot \(index)")
        }

        // It is not an error in Lox to redeclare a variable
        self.values[index] = value
    }

    /**
     Get the current value for the global storage at `index`.
     - throws: `UndefinedVariable` if the variable's declaration has not been
     executed (no value has ever been stored in the slot).
     - returns: The global variable's current value.
     */
    func readValue(at index: Int) throws -> Value
    {
        guard self.values.indices ~= index else {
            fatalError("Internal error: Invalid global slot \(index)")
        }

        guard let value = self.values[index] else {
            throw UndefinedVariable(name: self.name(for: index))
        }

        return value
    }

    /**
     Update the global storage at `index` to hold `value`.
     - throws: `UndefinedVariable` if the variable's declaration has not been
     executed (no value has ever been stored in the slot).
     */
    func storeValue(_ value: Value, at index: Int) throws
    {
        guard self.values.indices ~= index else {
            fatalError("Internal error: Invalid global slot \(index)")
        }

        guard self.values[index] != nil else {
            throw UndefinedVariable(name: self.name(for: index))
        }

        self.values[index] = value
    }

    /**
     Perform a reverse lookup in `names` to find the variable that corresponds
     to `index`.

     - remark: This is a linear search and should only be done for error
     reporting.
     */
    private func name(for index: Int) -> StringRef
    {
        guard let name = self.names.first(where: { $0.1.asInt == index })?.0 else {
            fatalError("Internal error: Undefined global slot \(index)")
        }

        return name
    }
}
