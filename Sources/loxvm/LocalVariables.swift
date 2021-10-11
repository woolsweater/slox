/**
 Bookkeeping for local variables during compilation.
 - remark: Effectively this permits simulating the stack, tracking identifiers
 and depths instead of values, so that the compiler can resolve variable
 references and emit the correct stack index to the byte code.
 */
struct LocalVariables
{
    /** Record for a single local variable. */
    struct Entry
    {
        /** The text of the variable's identifier. */
        let name: Substring

        /**
         The count of block scopes enclosing the variable. Until the variable's
         initializer expression has been compiled, this will be `nil`. Then it
         will be set to correspond to the compiler's `Scope` at the time the
         variable is defined.
         */
        var depth: Int?
    }

    /**
     An error indicating too many local variables are present in the current
     compilation context.
     */
    struct OutOfStorage : Error {}

    /**
     An error produced when trying to resolve a variable name that doesn't yet
     have a valid `depth.`
     */
    struct UninitializedVariable : Error {}

    // var only so we can `assert(isKnownUniquelyReferenced)`
    private var storage: Storage

    /**
     Create local variable storage with a limit of `capacity` entries.
     */
    init(capacity: Int)
    {
        self.storage = Storage.create(
            minimumCapacity: capacity,
            makingHeaderWith: { _ in 0 }
        ) as! Storage
    }
}

extension LocalVariables
{
    /**
     Remove all entries from the end of the list with the given `depth`.
     - remark: This should be used only when `depth` corresponds to the most
     recently-created scope in the compiler. If the depth of the newest entry is
     _higher_ than `depth`, nothing will be removed.
     - returns: The count of entries that were removed.
     */
    mutating func popFrame(at depth: Int) -> Int
    {
        assert(isKnownUniquelyReferenced(&self.storage), "Need CoW support")
        let popCount = self.currentFrame(ifAt: depth).count
        self.storage.pop(popCount)
        return popCount
    }

    /**
     Add the given value to the end of the list.
     - throws: `OutOfStorage` if too many entries are already present.
     */
    mutating func append(_ variable: Entry) throws
    {
        assert(isKnownUniquelyReferenced(&self.storage), "Need CoW support")
        try self.storage.append(variable)
    }

    /** Update the most recent entry's `depth` from `nil` to the given value. */
    mutating func markLastInitialized(with depth: Int)
    {
        assert(isKnownUniquelyReferenced(&self.storage), "Need CoW support")
        self.storage.updateLast({ $0.depth = depth })
    }

    /**
     Starting from the end of the list, return all entries with the given
     `depth`.
     - remark: This should be used only when `depth` corresponds to the most
     recently-created scope in the compiler. If the depth of the newest entry is
     _higher_ than `depth`, nothing will be returned.
     */
    func currentFrame(ifAt depth: Int) -> [Entry]
    {
        return self.storage.withEntries { (entries) in
            assert(depth >= (entries.last?.depth ?? 0))
            return entries.reversed().prefix(while: { $0.depth == depth })
        }
    }

    /**
     Starting from the most recently added variable, search backwards for
     `name`.
     - returns: The index corresponding to the most recent *initialized* entry
     matching `name` (`depth` is not `nil`), or `nil` if no valid candidate is
     found.
     */
    func resolve(_ name: Substring) -> Int?
    {
        return self.storage.withEntries { (entries) in
            let match = entries.lazy.enumerated()
                .reversed()
                .first(where: { $0.element.name == name && $0.element.depth != nil })

            return match?.offset
        }
    }
}

private extension LocalVariables
{
    /**
     The buffer holding the actual records for a `LocalVariables` instance. The
     header is the count of live, initialized entries.
     */
    final class Storage : ManagedBuffer<Int, Entry>
    {
        deinit
        {
            self.withUnsafeMutablePointers { (header, base) in
                _ = base.deinitialize(count: header.pointee)
            }
        }

        /**
         Execute `query` with a view of all the live entries -- those from the
         start of the raw storage through the current count.
         */
        func withEntries<T>(_ query: (UnsafeBufferPointer<Entry>) -> T) -> T
        {
            return self.withUnsafeMutablePointers { (header, base) in
                let entries = UnsafeBufferPointer(start: base, count: header.pointee)
                return query(entries)
            }
        }

        func updateLast(_ mutation: (inout Entry) -> Void)
        {
            self.withUnsafeMutablePointers { (header, base) in
                let lastIndex = header.pointee - 1
                precondition(lastIndex >= 0, "Cannot mutate empty 'LocalVariables'")
                mutation(&(base + lastIndex).pointee)
            }
        }

        /** Copy `entry` to the end of the buffer and increment the count. */
        func append(_ entry: Entry) throws
        {
            try self.withUnsafeMutablePointers { (header, base) in
                let count = header.pointee
                guard count < self.capacity else {
                    throw OutOfStorage()
                }
                (base + count).initialize(to: entry)
                header.pointee += 1
            }
        }

        /**
         Clear out the storage for the last `n` entries and adjust the count
         appropriately.
         */
        func pop(_ n: Int)
        {
            guard n > 0 else { return }
            self.withUnsafeMutablePointers { (header, base) in
                assert(header.pointee >= n)
                header.pointee -= n
                (base + header.pointee).deinitialize(count: n)
            }
        }
    }
}
