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
     Acquire a piece of memory to hold a value of the given type, which must
     be an `Object` subtype.
     */
    func allocateObject<T>(_ objectType: T.Type, kind: ObjectKind) -> UnsafeMutablePointer<T>
    {
        let allocation = self.reallocate(nil, oldSize: 0, newSize: MemoryLayout<T>.size)!
        let obj = allocation.bindMemory(to: Object.self, capacity: 1)
        obj.pointee.next = self.rootObject
        obj.pointee.kind = kind
        self.rootObject = obj
        return allocation.bindMemory(to: T.self, capacity: 1)
    }

    /**
     Allocate a buffer that can hold `size` objects of the given `type`.
     - precondition: `size` should be positive
     */
    func allocateBuffer<T>(of type: T.Type, size: Int) -> UnsafeMutableBufferPointer<T>
    {
        precondition(size > 0)
        let raw = self.reallocate(nil, oldSize: 0, newSize: size)!
        let base = raw.bindMemory(to: T.self, capacity: size)
        return UnsafeMutableBufferPointer<T>(start: base, count: size)
    }

    /** Walk the list of allocated objects and free them and their payloads. */
    private func freeObjects()
    {
        guard let first = self.rootObject else { return }
        for object in ObjectList(first: first) {
            switch object.pointee.kind {
                case .string:
                    let string = object.asStringRef().pointee
                    self.freeAllocation(string.chars, size: string.length + 1)
                    self.freeAllocation(object, size: MemoryLayout<ObjectString>.size)
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
