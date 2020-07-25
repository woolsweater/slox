import Foundation
import loxvm_object

/** A hash table for use by the Lox runtime. */
struct Table
{
    //FIXME: We will need COW here if VM needs to move tables around

    /** The number of entries present in the table */
    private var count: Int

    fileprivate enum Entry
    {
        /**
         A real key-value pair. The `key`'s `hash` is used to find
         the location in the table.
         */
        case live(key: StringRef, value: Value)

        /**
         A marker for a deleted entry. The location may be reused
         for a new key-value pair. Otherwise, on expansion this
         value will be discarded.
         */
        case tombstone
    }

    /**
     The allocation where the table stores its key-value pairs.
     - remark: The public entry points must ensure that this is
     non-zero-sized before interacting with it.
     */
    private var entries: Buffer!
    fileprivate typealias Buffer = UnsafeMutableBufferPointer<Entry?>

    private let allocator: MemoryManager

    /**
     Create an empty table that will use the given allocator to
     manage its storage.
     */
    init(allocator: MemoryManager)
    {
        self.count = 0
        // `entries` will be filled lazily, on first insertion
        self.entries = nil
        self.allocator = allocator
    }

    /**
     Reset the table, removing all entries.
     */
    mutating func deinitialize()
    {
        self.count = 0
        self.allocator.destroyBuffer(self.entries)
        self.entries = nil
    }
}

extension Table
{
    /**
     Get, set, or delete the value for the specified key.
     (Setting a key's value to `nil` will remove that entry if
     it is present.)
     */
    subscript(key: StringRef) -> Value?
    {
        get { self.value(for: key) }
        set
        {
            if let value = newValue {
                self.insert(value, for: key)
            }
            else {
                _ = self.deleteValue(for: key)
            }
        }
    }

    /**
     Look up `key` in the table and, if present, return its associated
     value.
     */
    func value(for key: StringRef) -> Value?
    {
        // Important: if `count` is 0, `entries` may be uninitialized
        guard self.count > 0 else { return nil }
        let slot = self.entries.findSlot(for: key)

        if case let .live(_, value) = slot.pointee {
            return value
        }
        else {
            return nil
        }
    }

    /**
     Add an entry to the table for the given key-value pair.
     - remark: If `key` is already present, the old value will
     be replaced by the new one.
     */
    mutating func insert(_ value: Value, for key: StringRef)
    {
        if self.needsExpansionOnInsertion {
            self.expand()
        }

        let slot = self.entries.findSlot(for: key)

        if slot.pointee == nil {
            // Tombstones are already included in the count
            self.count += 1
        }

        slot.pointee = .live(key: key, value: value)
    }

    /** Remove the entry for `key` from the table, if it is present. */
    mutating func deleteValue(for key: StringRef) -> Bool
    {
        guard self.count > 0 else { return false }

        let slot = self.entries.findSlot(for: key)

        guard slot.pointee != nil else { return false }

        // Mark the slot as unused, but preserve its place in
        // its probe sequence
        slot.pointee = .tombstone
        return true
    }

    /**
     Take each entry from the given table and insert it into
     this one.
     - remark: The current table will be expanded as needed
     during the process.
     */
    mutating func copyEntries(from other: Table)
    {
        guard other.count > 0 else { return }

        for entry in other.entries {
            guard case let .live(key, value) = entry else {
                continue
            }
            self.insert(value, for: key)
        }
    }
}

private extension Table
{
    private static let maximumLoad = 0.75
    private static let expansionFactor = 1.6

    private var capacity: Int { self.entries?.count ?? 0 }
    private var maxiumumCount: Int { self.capacity.scaled(by: Table.maximumLoad) }
    private var needsExpansionOnInsertion: Bool { self.count + 1 > self.maxiumumCount }
    private var expandedCapacity: Int { self.count.scaled(by: Table.expansionFactor) }

    private mutating func expand()
    {
        let newEntries = self.allocator.allocateBuffer(of: Table.Buffer.Element.self,
                                                       count: self.expandedCapacity)

        newEntries.initialize(repeating: nil)

        // We will remove tombstones, and therefore their effect on count,
        // while copying over.
        self.count = 0
        for entry in self.entries {
            guard case let .live(key, _) = entry else { continue }
            let slot = newEntries.findSlot(for: key)
            slot.pointee = entry
            self.count += 1
        }

        self.allocator.destroyBuffer(self.entries)
        self.entries = newEntries
    }
}

private extension Table.Buffer
{
    typealias Slot = UnsafeMutablePointer<Element>

    func findSlot(for key: StringRef) -> Slot
    {
        var index = Int(key.pointee.hash) % self.count
        var tombstoneSlot: Slot? = nil

        while let entry = self[index] {

            switch entry {
                case let .live(key: candidateKey, value: _):
                    if candidateKey == key {
                        return self.slot(at: index)
                    }
                case .tombstone:
                    // Only save the first tombstone
                    if tombstoneSlot == nil {
                        tombstoneSlot = self.slot(at: index)
                    }
            }

            index = self.wrappingIndex(after: index)
        }

        // Once we've determined that the sought key is not present in
        // the probe sequence, return the earliest usable slot
        return tombstoneSlot ?? self.slot(at: index)
    }

    private func slot(at index: Index) -> Slot { self.baseAddress! + index }

    private func wrappingIndex(after index: Index) -> Index
    {
        guard
            let newIndex = self.index(index, offsetBy: 1, limitedBy: self.endIndex),
            newIndex != self.endIndex else
        {
            return self.startIndex
        }

        return newIndex
    }
}

private extension Int
{
    func scaled(by double: Double) -> Int
    {
        self |> Double.init(_:) |> { $0 * double } |> Int.init(_:)
    }
}
