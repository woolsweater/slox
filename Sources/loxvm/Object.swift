import loxvm_object

typealias CStr = UnsafeMutableBufferPointer<Int8>
typealias ConstCStr = UnsafeBufferPointer<Int8>

extension ObjectRef
{
    /**
     "Cast" a generic `ObjectRef` to a `StringRef`.
     - warning: Behavior is undefined if there is not an `ObjectString` at the
     pointed-to location.
     */
    func asStringRef() -> StringRef
    {
        assert(self.pointee.kind == .string)
        let raw = UnsafeMutableRawPointer(self)
        return raw.assumingMemoryBound(to: ObjectString.self)
    }
}

extension StringRef
{
    /**
     Given a chunk of memory, sized for an `ObjectString` and whose `header` is already
     initialized, configure it to also own the given character buffer.
     */
    static func initialize(_ allocation: StringRef, takingChars utf8: CStr) -> StringRef
    {
        allocation.pointee.chars = utf8.baseAddress!
        allocation.pointee.length = utf8.count
        return allocation
    }

    /**
     Given a chunk of memory, sized for an `ObjectString` and whose `header` is already
     initialized, copy the given characters into the provided buffer and finish initialization
     of the `ObjectString`.
     */
    static func initialize(_ allocation: StringRef, copying lexeme: ConstCStr, into buffer: CStr) -> StringRef
    {
        let stringLength = lexeme.count + 1
        assert(buffer.count == stringLength)
        memcpy(buffer.baseAddress, lexeme.baseAddress, lexeme.count)
        buffer[lexeme.count] = 0x0
        return self.initialize(allocation, takingChars: buffer)
    }

    /** "Cast" a `StringRef` to an `ObjectRef`. */
    func asBaseRef() -> ObjectRef
    {
        let raw = UnsafeMutableRawPointer(self)
        return raw.assumingMemoryBound(to: Object.self)
    }
}
