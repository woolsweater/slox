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
    /**
     Given a `StringRef` whose `header` is already initialized, configure
     it to also own the given character buffer.
     */
    func initialize(with chars: CStr)
    {
        self.pointee.chars = chars.baseAddress!
        self.pointee.length = chars.count - 1
    }
}
