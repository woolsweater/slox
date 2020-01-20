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
        allocation.pointee.length = utf8.count - 1
        return allocation
    }

    /**
     Given a chunk of memory, sized for an `ObjectString` and whose `header` is already
     initialized, copy the given characters into the provided buffer and finish initialization
     of the `ObjectString`.
     */
    static func initialize(_ allocation: StringRef, copying terminatedLexeme: ConstCStr, into buffer: CStr) -> StringRef
    {
        assert(buffer.count == terminatedLexeme.count)
        memcpy(buffer.baseAddress, terminatedLexeme.baseAddress, terminatedLexeme.count)
        return self.initialize(allocation, takingChars: buffer)
    }

    /** "Cast" a `StringRef` to an `ObjectRef`. */
    func asBaseRef() -> ObjectRef
    {
        let raw = UnsafeMutableRawPointer(self)
        return raw.assumingMemoryBound(to: Object.self)
    }
}
