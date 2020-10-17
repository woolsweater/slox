import XCTest
@testable import loxvm_testable
@testable import loxvm_object

/** Tests for `HashTable`. */
class HashTableTests : XCTestCase
{
    /**
     Source of `StringRef`s to use as test input.
     - remark: The hash table under test will use a separate allocator.
     */
    private var memoryManager: MemoryManager!

    override func setUp()
    {
        super.setUp()
        self.memoryManager = MemoryManager()
    }

    override func tearDown()
    {
        self.memoryManager = nil
        super.tearDown()
    }

    /**
     Test the table's behavior when expanding, first from an empty state.
     - remark: The table should start with a small size, and it
     should expand before it is entirely filled.
     */
    func testExpansion() throws
    {
        let table = self.createTable()
        // Add one entry so that the buffer is created
        table.internString(self.memoryManager.createRandomObjectString())
        let originalBufferCount = table.buffer.count
        XCTAssert(originalBufferCount < 100)
        let initialTestKeys = self.memoryManager.createRandomObjectStrings(count: originalBufferCount)

        // Find first expansion point
        var expansionPoint: Int? = nil
        for (i, key) in initialTestKeys.enumerated() {
            table.internString(key)

            let insertionCount = i + 2    // +1 for 0-based index, +1 for initial item (before the loops)
            XCTAssertEqual(insertionCount, table.count)
            if table.buffer.count > originalBufferCount && expansionPoint == nil {
                expansionPoint = insertionCount
            }
            let (empty, live, tombstones) = table.buffer.entryCounts
            XCTAssertEqual(table.buffer.count - insertionCount, empty)
            XCTAssertEqual(insertionCount, live)
            XCTAssertEqual(0, tombstones)
        }

        XCTAssert(try XCTUnwrap(expansionPoint) < originalBufferCount)

        // Find the next expansion point
        let expandedBufferCount = table.buffer.count
        expansionPoint = nil
        let moreTestKeys = self.memoryManager.createRandomObjectStrings(count: expandedBufferCount - originalBufferCount)
        for (i, key) in moreTestKeys.enumerated() {
            table.internString(key)

            let insertionCount = i + originalBufferCount + 2    // +1 for 0-based index, +1 for initial item (before the loops)
            XCTAssertEqual(insertionCount, table.count)
            if table.buffer.count > expandedBufferCount && expansionPoint == nil {
                expansionPoint = insertionCount
            }
            let (empty, live, tombstones) = table.buffer.entryCounts
            XCTAssertEqual(table.buffer.count - insertionCount, empty)
            XCTAssertEqual(insertionCount, live)
            XCTAssertEqual(0, tombstones)
        }

        XCTAssert(try XCTUnwrap(expansionPoint) < expandedBufferCount)

        // All the inserted items should be present. Since they were "interned"
        // their value is just `Lox.Value.nil`
        for key in initialTestKeys {
            XCTAssertNotNil(table.findString(matching: key))
            XCTAssertEqual(.nil, table.value(for: key))
        }

        for key in moreTestKeys {
            XCTAssertNotNil(table.findString(matching: key))
            XCTAssertEqual(.nil, table.value(for: key))
        }
    }

    /**
     Generate a lot of random strings and "intern" them.
     - remark: Minimal assertions here and a redundant operation;
     partially we just want this test to flush out memory errors.
     */
    func testInterning()
    {
        let table = self.createTable()
        var previousInput: StringRef? = nil
        for input in self.memoryManager.createRandomObjectStrings(count: 10_000) {
            if let previous = previousInput {
                XCTAssertNotNil(table.findString(matching: previous))
                XCTAssertEqual(.nil, table.value(for: previous))
            }
            table.internString(input)
            if let previous = previousInput {
                table.internString(previous)
            }
            previousInput = input
        }
    }

    /**
     Test removing entries from the table.
     - remark: The table should transform the live entry into a tombstone, and
     lookup of either the deleted key itself or the value should return `Swift.nil`.
     */
    func testDelete()
    {
        let table = self.createTable()
        let keys = self.memoryManager.createRandomObjectStrings(count: 10_000)

        for key in keys {
            table.internString(key)
        }

        let deletedKeys = keys.filter({ (_) in Int.random(in: 0..<3) == 0 })
        for (i, key) in deletedKeys.enumerated() {
            XCTAssertTrue(table.deleteValue(for: key))
            XCTAssertEqual(i + 1, table.buffer.entryCounts.tombstone)
        }

        for key in deletedKeys {
            XCTAssertNil(table.findString(matching: key))
            XCTAssertNil(table.value(for: key))
        }
    }

    private func createTable() -> HashTable
    {
        HashTable(allocator: { UnsafeMutableBufferPointer.allocate(capacity: $0) },
                deallocator: { $0.deallocate() })
    }
}

private extension MemoryManager
{
    func createObjectString(from string: String) -> StringRef
    {
        return string.withCString {
            let buf = UnsafeBufferPointer(start: $0, count: string.utf8.count)
            return self.createString(copying: buf)
        }
    }

    func createRandomObjectString() -> StringRef
    {
        let length = Int.random(in: 8...32)
        let bytes = (0..<length).map({ (_) in Int8.random(in: 0x22...0x7e) })
        return bytes.withUnsafeBufferPointer {
            self.createString(copying: $0)
        }
    }

    func createRandomObjectStrings(count: Int) -> [StringRef]
    {
        (0..<count).map({ (_) in self.createRandomObjectString() })
    }
}

private extension HashTable.Buffer
{
    /** The respective counts of the three types of entries in the table. */
    var entryCounts: (empty: Int, live: Int, tombstone: Int)
    {
        return self.reduce(into: (0, 0, 0)) {
            (counts, next) in
            switch next {
                case .none: counts.0 += 1
                case .live?: counts.1 += 1
                case .tombstone?: counts.2 += 1
            }
        }
    }
}
