import Foundation
import loxvm_object

/** Handles heap allocations on behalf of the VM and its `Compiler`. */
class MemoryManager
{
    /**
     The most recently-allocated object; provides access to all object allocations
     as a linked list via the `next` pointer.
     */
    private var rootObject: ObjectRef?

    deinit { self.freeObjects() }

    /**
     Change the size of the allocation at the given pointer to `newSize`; if `newSize`
     is 0, this frees the allocation.
     */
    @discardableResult
    func reallocate(_ previous: UnsafeMutableRawPointer?, oldSize: Int, newSize: Int) -> UnsafeMutableRawPointer?
    {
        if newSize <= 0 {
            free(previous)
            return nil
        }
        else {
            return realloc(previous, newSize)
        }
    }

    /**
     Allocate and initialize a Lox string, copying the given C string into the
     `chars` segment of the allocation.
     */
    func createString(copying chars: ConstCStr) -> StringRef
    {
        let string = self.createObject(ObjectString.self,
                                       trailingSize: chars.count)
        string.initialize(copying: chars)
        return string
    }

    /**
     Allocate and initialize a Lox string, copying the contents of the two
     strings into the new string's `chars` buffer.
     */
    func createString(concatenating left: StringRef, _ right: StringRef) -> StringRef
    {
        let unterminatedLength = left.pointee.length + right.pointee.length
        let string = self.createObject(ObjectString.self,
                                       trailingSize: unterminatedLength + 1)
        string.concatenate(left, right)
        return string
    }

    /**
     Allocate a buffer that can hold `count` objects of the given `type`.
     - precondition: `size` should be positive
     */
    func allocateBuffer<T>(of type: T.Type, count: Int) -> UnsafeMutableBufferPointer<T>
    {
        precondition(count > 0)
        let size = count * MemoryLayout<T>.stride
        let raw = self.reallocate(nil, oldSize: 0, newSize: size)!
        let base = raw.bindMemory(to: T.self, capacity: count)
        return UnsafeMutableBufferPointer<T>(start: base, count: count)
    }

    /**
     Acquire a piece of memory to hold a value of the given type, which must
     be an `Object` subtype, plus any required trailing member space, and
     initialize its `header`.
     */
    private func createObject<T>(_ objectType: T.Type, trailingSize: Int = 0)
        -> UnsafeMutablePointer<T> where T : LoxObjectType
    {
        let size = MemoryLayout<T>.size + trailingSize
        guard let allocation = self.reallocate(nil, oldSize: 0, newSize: size) else {
            fatalError("Failed allocation for '\(T.self)' instance")
        }
        let obj = allocation.bindMemory(to: objectType, capacity: 1)
        obj.pointee.header.next = self.rootObject
        obj.pointee.header.kind = objectType.kind
        self.rootObject = obj.asBaseRef()
        return obj
    }

    /** Walk the list of allocated objects and free them and their payloads. */
    private func freeObjects()
    {
        guard let first = self.rootObject else { return }
        for object in ObjectList(first: first) {
            switch object.pointee.kind {
                case .string:
                    let string = object.asStringRef().pointee
                    let size = MemoryLayout<ObjectString>.size + string.length + 1
                    self.freeAllocation(object, size: size)
            }
        }
        self.rootObject = nil
    }

    @inline(__always)
    private func freeAllocation(_ pointer: UnsafeMutableRawPointer, size: Int)
    {
        self.reallocate(pointer, oldSize: size, newSize: 0)
    }
}

/** Iterator over a linked list of `ObjectRef`s. */
private struct ObjectListIterator : IteratorProtocol
{
    private var current: ObjectRef

    init(first: ObjectRef)
    {
        self.current = first
    }

    mutating func next() -> ObjectRef?
    {
        guard let next = self.current.pointee.next else { return nil }
        defer { self.current = next }
        return self.current
    }
}

/**
 `Sequence`-based access to the linked list of `ObjectRef`s originating at
 a given head.
 */
private struct ObjectList : Sequence
{
    let first: ObjectRef

    func makeIterator() -> ObjectListIterator
    {
        return ObjectListIterator(first: self.first)
    }
}