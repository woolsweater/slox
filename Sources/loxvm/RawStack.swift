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
        self.top = buffer.baseAddress!
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
        assert(self.top < self.buffer.baseAddress! + self.buffer.endIndex)
        self.top.initialize(to: value)
        self.top += 1
    }

    /** Remove and return the value at the top of the stack. */
    mutating func pop() -> Element
    {
        assert(self.top > self.buffer.baseAddress!)
        self.top -= 1
        return self.top.move()
    }

    /** Return the value at the given distance from the top of the stack, keeping it in place. */
    func peek(distance: Int = 0) -> Element
    {
        let address = self.top - 1 - distance
        assert(address >= self.buffer.baseAddress!)
        return address.pointee
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
