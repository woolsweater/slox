import Foundation
import loxvm_object

/** A hash table for use by the Lox runtime. */
class HashTable
{
    enum Entry
    {
        /**
         A real key-value pair. The `key`'s `hash` is used to find
         the location in the table.
         */
        case live(key: StringRef, value: Value)

        /**
         A marker for a deleted entry, preserving the probe
         sequence. The location may be reused for a new
         key-value pair. Otherwise, on expansion this entry
         will be discarded.
         */
        case tombstone
    }

    /** The underlying storage for the table. */
    typealias Buffer = UnsafeMutableBufferPointer<Entry?>
    /** A function that can allocate a new `Buffer` of the given capacity. */
    typealias Allocator = (Int) -> Buffer
    /** A function that can destroy a `Buffer` */
    typealias Deallocator = (Buffer) -> Void

    /** The number of entries actually present in the table. */
    private(set) var count: Int

    /**
     The allocation where the table stores its key-value pairs.
     - remark: The public entry points must ensure that this is
     non-zero-sized before interacting with it.
     */
    private var entries: Buffer!

    private let allocate: Allocator
    private let deallocate: Deallocator

    /**
     Create an empty table that will use the given allocator to
     manage its storage.
     */
    init(allocator: @escaping Allocator, deallocator: @escaping Deallocator)
    {
        self.count = 0
        // `entries` will be populated lazily, on first insertion
        self.entries = nil
        self.allocate = allocator
        self.deallocate = deallocator
    }

    /** Reset the table, removing all entries. */
    deinit
    {
        self.count = 0
        self.deallocate(self.entries)
        self.entries = nil
    }
}

extension HashTable
{
    /**
     Look for a key whose contents are equal to the given
     characters, returning it if it exists in the table.
     - remark: This can be used _before_ creating a new `StringRef`
     and storing it in the table to ensure that it is unique.
     */
    func findString(matching chars: ConstCStr) -> StringRef?
    {
        // Important: if `count` is 0, `entries` may be uninitialized
        guard self.count > 0 else { return nil }
        let hash = loxHash(chars)
        return self.entries.findString(matching: chars, with: hash)
    }

    /**
     Look for a key equal to the given `StringRef`, returning
     it if it exists in the table.
     */
    func findString(matching string: StringRef) -> StringRef?
    {
        // Important: if `count` is 0, `entries` may be uninitialized
        guard self.count > 0 else { return nil }
        let chars = ConstCStr(start: string.chars, count: string.pointee.length + 1)
        return self.entries.findString(matching: chars,
                                       with: string.pointee.hash)
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
    func insert(_ value: Value, for key: StringRef)
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

    /**
     Add the given string to the table as a new key that is
     known to be unique. `.nil` is stored as the value.
     */
    func internString(_ string: StringRef)
    {
        self.insert(.nil, for: string)
    }

    /** Remove the entry for `key` from the table, if it is present. */
    func deleteValue(for key: StringRef) -> Bool
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
    func copyEntries(from other: HashTable)
    {
        guard other.count > 0 else { return }

        for case let .live(key, value) in other.entries {
            self.insert(value, for: key)
        }
    }
}

private extension HashTable
{
    struct Size
    {
        static let minimumCapacity = 8
        static let maximumLoad = 0.75
        static let expansionFactor = 1.6
    }

    private var capacity: Int { self.entries?.count ?? 0 }
    private var maxiumumCount: Int { self.capacity.scaled(by: Size.maximumLoad) }
    private var needsExpansionOnInsertion: Bool { self.count + 1 > self.maxiumumCount }
    private var expandedCapacity: Int { max(Size.minimumCapacity, self.capacity.scaled(by: Size.expansionFactor)) }

    private func expand()
    {
        let newEntries = self.allocate(self.expandedCapacity)

        newEntries.initialize(repeating: nil)

        if let existingEntries = self.entries {
            // We will remove tombstones, and therefore their effect on count,
            // while copying over.
            self.count = 0
            for entry in existingEntries {
                guard case let .live(key, _) = entry else { continue }
                let slot = newEntries.findSlot(for: key)
                slot.pointee = entry
                self.count += 1
            }

            self.deallocate(self.entries)
        }

        self.entries = newEntries
    }
}

private extension HashTable.Buffer
{
    /** A location in the buffer */
    typealias Slot = UnsafeMutablePointer<Element>

    /**
     Locate the expected slot in the buffer for the given key's hash,
     then, if it is not there, probe forward until either we find it or
     hit an empty slot.
     If the desired key is found, its slot is returned. Otherwise,
     the first usable slot in the sequence is returned: either the
     first tombstone, or the empty slot at the end.
     */
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

    /**
     Check whether a `StringRef` already exists in the table with the
     given contents. The character buffer's hash is passed for convenience
     in the comparison step.
     - returns: The `StringRef` with contents identical to the passed
     characters, or `nil` if no such entry exists.
     */
    func findString(matching chars: ConstCStr, with hash: UInt32) -> StringRef?
    {
        var index = Int(hash) % self.count
        while let entry = self[index] {
            defer { index = self.wrappingIndex(after: index) }
            guard case let .live(key, _) = entry else { continue }

            if key.matches(chars, and: hash) {
                return key
            }
        }

        return nil
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

private extension StringRef
{
    /**
     Compare this `StringRef` for equivalence with a character buffer/hash
     pair.
     - remark: Easy comparisons first: length and hash; actual
     byte-by-byte equality is only checked if those pass.
     */
    func matches(_ chars: ConstCStr, and hash: UInt32) -> Bool
    {
        return self.pointee.length == (chars.count - 1) &&
            self.pointee.hash == hash &&
            strncmp(self.chars, chars.baseAddress!, self.pointee.length) == 0
    }
}

private extension Int
{
    func scaled(by double: Double) -> Int
    {
        self |> Double.init(_:) |> { $0 * double } |> Int.init(_:)
    }
}

#if DEBUG
extension HashTable
{
    /** Access in unit tests to the table's buffer */
    var buffer: Buffer { self.entries }
}
#endif
