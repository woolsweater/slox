import Foundation

/**
 Manages a buffer of typed memory, allowing pushes and pops to and
 from the end.
 */
struct RawStack<Element>
{
    //FIXME: We will need COW here if VM needs to move its stack around

    /** The underlying storage. */
    private let buffer: UnsafeMutableBufferPointer<Element>
    /** The location at which the next element will be stored. */
    private var top: UnsafeMutablePointer<Element>

    /** Create a stack that can hold `size` elements. */
    init(size: Int, allocator: MemoryManager)
    {
        self.buffer = allocator.allocateBuffer(count: size)
        self.top = self.buffer.baseAddress!
    }

    /**
     Deinitialize and free the stack's allocation.
     - warning: This leaves the stack in an unusable
     and *unsafe* state.
     */
    func destroy(allocator: MemoryManager)
    {
        allocator.destroyBuffer(self.buffer)
    }

    /** Add a value to the top of the stack. */
    mutating func push(_ value: Element)
    {
        precondition(self.top < self.buffer.baseAddress! + self.buffer.endIndex)
        self.top.initialize(to: value)
        self.top += 1
    }

    /** Remove and return the value at the top of the stack. */
    mutating func pop() -> Element
    {
        precondition(self.top > self.buffer.baseAddress!)
        self.top -= 1
        return self.top.move()
    }

    /** Remove and discard all values currently in the stack. */
    mutating func reset()
    {
        self.top = self.buffer.baseAddress!
    }

    /**
     Return the value at the given distance from the top of the stack, keeping
     it in place.
     */
    func peek(distance: Int = 0) -> Element
    {
        let address = self.top - 1 - distance
        precondition(address >= self.buffer.baseAddress!)
        return address.pointee
    }

    /**
     Treating the stack as an array where 0 is the _bottom_, access the value
     at index `i`.
     - remark: This is required for access to local variables, which are pushed
     first in the stack for any given scope.
     */
    subscript (localSlot i: Int) -> Element
    {
        get {
            let address = self.address(at: i)
            return address.pointee
        }
        set {
            let address = self.address(at: i)
            address.pointee = newValue
        }
    }

    /**
     The storage location `i` places from the start of `buffer` (which is the
     bottom of the stack).
     */
    private func address(at i: Int) -> UnsafeMutablePointer<Element>
    {
        precondition(i >= 0)
        let address = self.buffer.baseAddress! + i
        precondition(address < self.top, "Internal error: attempt to access invalid stack slot \(i)")
        return address        
    }
}

#if DEBUG_TRACE_EXECUTION
extension RawStack
{
    /** Print the current contents of the stack in a row. */
    func printContents()
    {
        var slot = self.buffer.baseAddress!
        while slot != self.top {
            print("[ ", terminator: "")
            print(slot.pointee, terminator: "")
            print(" ]", terminator: "")
            slot += 1
        }
        print("")
    }
}
#endif
