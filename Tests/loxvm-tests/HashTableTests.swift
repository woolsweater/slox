import XCTest
@testable import loxvm_testable
@testable import loxvm_object

/** Tests for `HashTable`. */
class HashTableTests : XCTestCase
{
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
     Test inserting strings into the table
     */
    func testInsert()
    {
        let testKeys = ["Hello", "world", "Caffè", "\u{1f600}", "Foobar", "xyzzy", "frogBlast", "ventCore"].map({
            self.memoryManager.createObjectString(from: $0)
        })
        let table = self.createTable()

        for (i, key) in testKeys[..<6].enumerated() {
            table.insert(.nil, for: key)

            let insertionCount = i + 1
            XCTAssertEqual(insertionCount, table.count)
            XCTAssertEqual(8, table.buffer.count)
            let (empty, live, tombstones) = table.buffer.entryCounts
            XCTAssertEqual(8 - insertionCount, empty)
            XCTAssertEqual(insertionCount, live)
            XCTAssertEqual(0, tombstones)
        }

        for (i, key) in testKeys[6...].enumerated() {
            table.insert(.nil, for: key)

            let insertionCount = i + 7
            XCTAssertEqual(insertionCount, table.count)
            XCTAssertEqual(12, table.buffer.count)
            let (empty, live, tombstones) = table.buffer.entryCounts
            XCTAssertEqual(12 - insertionCount, empty)
            XCTAssertEqual(insertionCount, live)
            XCTAssertEqual(0, tombstones)
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
}

private extension HashTable.Buffer
{
    var entryCounts: (empty: Int, live: Int, tombstone: Int) {
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
