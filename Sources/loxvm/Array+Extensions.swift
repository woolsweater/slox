extension Array
{
    /** Return all elements in the array, leaving it empty. */
    mutating func moveAll() -> Self
    {
        defer { self.removeAll() }
        return self
    }

    /**
     Directly change the value of the last element using the given function.
     - warning: Traps if the array is empty.
     */
    mutating func mutateLast(_ mutate: (inout Element) -> Void)
    {
        precondition(!(self.isEmpty))
        let lastIndex = self.indices.last!
        mutate(&self[lastIndex])
    }
}
