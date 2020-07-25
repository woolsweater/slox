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
        __StringRef_chars(self)
    }

    /**
     Given a `StringRef` whose `header` is already initialized, copy
     the given C string into its `chars` allocation.
     */
    func initialize(copying chars: ConstCStr)
    {
        precondition(chars.baseAddress != nil && chars.count > 0)
        self.pointee.length = chars.count - 1
        // `chars.count` includes the NUL
        self.chars.assign(from: chars.baseAddress!, count: chars.count)
        self.initializeHash()
    }

    /**
     Given a `StringRef` whose `header` is initialized, copy the contents of
     the two Lox strings into its `chars` allocation.
     */
    func concatenate(_ left: StringRef, _ right: StringRef)
    {
        let leftLength = left.pointee.length
        let rightLength = right.pointee.length
        let length = leftLength + rightLength

        self.chars.copyChars(from: left)
        self.chars.advanced(by: leftLength).copyChars(from: right)
        self.pointee.length = length
        self.chars[length] = 0x0
        self.initializeHash()
    }

    /** Calculate and store the "FNV-1a" hash of the characters in the string */
    private func initializeHash()
    {
        var hash: UInt32 = 2166136261

        for byte in UnsafeBufferPointer(start: self.chars, count: self.pointee.length) {
            let paddedByte = byte |> UInt8.init(bitPattern:) |> UInt32.init(_:)
            hash ^= paddedByte
            hash &*= 16777619
        }

        self.pointee.hash = hash
    }
}

private extension UnsafeMutablePointer where Pointee == CChar
{
    func copyChars(from string: StringRef)
    {
        self.assign(from: string.chars,
                    count: string.pointee.length)
    }
}
