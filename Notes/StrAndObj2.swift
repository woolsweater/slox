import Foundation

enum Object
{
    enum Kind
    {
        case string
    }

    struct Base
    {
        let kind: Kind
        var nextObject: BaseRef? = nil

        init(kind: Kind) { self.kind = kind }
    }

    struct String
    {
        typealias Chars = UnsafeMutableBufferPointer<UInt8>

        let base: Base = Base(kind: .string)
        var nextObject: BaseRef? = nil
        let chars: Chars

        init(chars: Chars) { self.chars = chars }
    }

    typealias Ref<T> = UnsafePointer<T>
    typealias BaseRef = Ref<Base>
    typealias StringRef = Ref<String>
}

extension Object.Base
{
    var isStr: Bool { self.kind == .string }
}

extension Object.BaseRef
{
    func asStr() -> Object.StringRef
    {
        assert(self.pointee.isStr)
        return self.downcast(to: Object.String.self)
    }


    private func downcast<T>(to type: T.Type) -> Object.Ref<T>
    {
        let raw = UnsafeRawPointer(self)
        return raw.bindMemory(to: T.self, capacity: 1)
    }
}

extension Object.StringRef
{
    init<C : Collection>(bytes: C) where C.Element == UInt8
    {
        let chars = Object.String.Chars(bytes: bytes)
        self.init(chars: chars)
    }

    private init(chars: Object.String.Chars)
    {
        let p = UnsafeMutablePointer<Object.String>.allocate(capacity: 1)
        p.initialize(to: Object.String(chars: chars))
        self.init(p)
    }

    func toHostString() -> Swift.String
    {
        return String(bytes: self.pointee.chars, encoding: .utf8)!
    }
}

extension Object.String.Chars
{
    init<C : Collection>(bytes: C) where C.Element == UInt8
    {
        self.init(unterminatedCount: bytes.count)
        let (_, initializedCount) = self.initialize(from: bytes)
        guard initializedCount == bytes.count else {
            fatalError("Could not complete copy")
        }
        self[bytes.count] = 0x00
    }

    private init(unterminatedCount: Int)
    {
        let terminatedCount = unterminatedCount + 1
        let start = UnsafeMutablePointer<UInt8>.allocate(capacity: terminatedCount)
        self.init(start: start, count: terminatedCount)
    }
}

extension Object.Ref
{
    func asBaseObject() -> Object.BaseRef
    {
        let raw = UnsafeRawPointer(self)
        return raw.bindMemory(to: Object.Base.self, capacity: 1)
    }
}

let hello: [UInt8] = [0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21]
let s = Object.StringRef(bytes: hello)
let o = s.asBaseObject()
let s2 = o.asStr()
print(s2.toHostString())
