import loxvm_object

typealias CStr = UnsafeMutableBufferPointer<Int8>
typealias ConstCStr = UnsafeBufferPointer<Int8>

/**
 One of the C structs in loxvm_object that "inherits"
 from `Object`.
 */
protocol LoxObjectType
{
    /** The tag for this object type. */
    static var kind: ObjectKind { get }
    /** The bookkeeping data common to all objects. */
    var header: Object { get set }
}

extension UnsafeMutablePointer where Pointee : LoxObjectType
{
    /** "Cast" a specific object pointer to a generic `ObjectRef`. */
    func asBaseRef() -> ObjectRef
    {
        let raw = UnsafeMutableRawPointer(self)
        return raw.assumingMemoryBound(to: Object.self)
    }
}

extension ObjectString : LoxObjectType
{
    static let kind: ObjectKind = .string
}

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
    var chars: UnsafeMutablePointer<CChar>
    {
        return __ObjectString_chars(self)
    }

    /**
     Given a `StringRef` whose `header` is already initialized, copy
     the given C string into its `chars` allocation.
     */
    func initialize(copying chars: ConstCStr)
    {
        // `chars.count` includes NUL
        memcpy(self.chars, chars.baseAddress!, chars.count)
        self.pointee.length = chars.count - 1
    }

    /**
     Given a `StringRef` whose `header` is initialized, copy the contents of
     the two Lox strings into its `chars` allocation.
     */
    func concatenate(_ left: StringRef, _ right: StringRef)
    {
        memcpy(self.chars, left.chars, left.pointee.length)
        memcpy(self.chars + left.pointee.length, right.chars, right.pointee.length)
        let unterminatedLength = left.pointee.length + right.pointee.length
        self.chars[unterminatedLength] = 0x0
        self.pointee.length = unterminatedLength
    }
}
