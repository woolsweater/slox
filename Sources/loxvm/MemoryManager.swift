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

    func reallocateBuffer<T>(_ previous: UnsafeMutableBufferPointer<T>?, newCount: Int) -> UnsafeMutableBufferPointer<T>?
    {
        let newSize = MemoryLayout<T>.stride * newCount
        let oldSize = MemoryLayout<T>.stride * (previous?.count ?? 0)
        let raw = self.reallocate(previous?.baseAddress, oldSize: oldSize, newSize: newSize)
        let base = raw?.bindMemory(to: T.self, capacity: newCount)
        // Track these and error at shutdown for leaks?
        return base.flatMap({ UnsafeMutableBufferPointer(start: $0, count: newCount) })
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
     - parameter type: The element type that will be stored in the buffer.
     - parameter count: The desired capacity of the new buffer.
     - returns: An *uninitialized* buffer large enough to hold `count` instances of
     its element type.
     */
    func allocateBuffer<T>(of type: T.Type = T.self, count: Int) -> UnsafeMutableBufferPointer<T>
    {
        precondition(count > 0)
        return self.reallocateBuffer(nil, newCount: count)!
    }

    /**
     Mark some memory that was previously obtained from `allocateBuffer` as unused.
     */
    func destroyBuffer<T>(_ buffer: UnsafeMutableBufferPointer<T>)
    {
        guard let pointer = buffer.baseAddress else { return }
        pointer.deinitialize(count: buffer.count)
        self.freeAllocation(pointer, size: buffer.byteSize)
    }

    func destroyObject<T>(_ object: UnsafeMutablePointer<T>) where T : LoxObjectType
    {
        guard let root = self.rootObject else {
            fatalError("The argument object is unknown to the manager!")
        }
        let toDestroy = object.asBaseRef()
        guard let previous = ObjectList(first: root).objectBefore(toDestroy) else {
            fatalError("Nonexistence!")
        }

        previous.pointee.next = toDestroy.pointee.next
        switch toDestroy.pointee.kind {
            case .string:
                let string = toDestroy.asStringRef().pointee
                let size = MemoryLayout<ObjectString>.size + string.length + 1
                self.freeAllocation(toDestroy, size: size)
        }
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

    func objectBefore(_ object: ObjectRef) -> ObjectRef?
    {
        self.first(where: { $0.pointee.next == object })
    }
}

private extension UnsafeMutableBufferPointer
{
    /** The size of the allocation contained in this buffer. */
    var byteSize: Int { self.count * MemoryLayout<Element>.stride }
}
