import Foundation

enum ObjType {
    case instance, str
}

struct Obj {
    let type: ObjType
}

typealias CharPtr = UnsafeMutableBufferPointer<UInt8>

extension CharPtr {
    init(capacity: Int) {
        let start = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        self.init(start: start, count: capacity)
    }
}

// "Subtype" of Obj
struct Str {
    let type: ObjType = .str
    let chars: CharPtr

    init(chars: CharPtr) {
        self.chars = chars
    }
}

typealias ObjPtr = UnsafePointer<Obj>
typealias StrPtr = UnsafePointer<Str>

extension StrPtr {
    init(chars: CharPtr) {
        let p = UnsafeMutablePointer<Str>.allocate(capacity: 1)
        p.initialize(to: Str(chars: chars))
        self.init(p)
    }
}

func unsafeUpcast<T>(_ value: UnsafePointer<T>) -> ObjPtr {
    // In C, `return (Obj *)(void *)value;`
    let raw = UnsafeRawPointer(value)
    return raw.bindMemory(to: Obj.self, capacity: 1)
}

extension ObjPtr {
    func asStr() -> StrPtr {
        assert(self.pointee.type == .str)
        // In C, `return (Str *)(void *)self;`
        let raw = UnsafeRawPointer(self)
        return raw.bindMemory(to: Str.self, capacity: 1)
    }
}

let bytes: [UInt8] = [0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21]
// buffer.len = /* find size of bytes */
// buffer.payload = malloc(sizeof(uint8_t) * buffer.len);
// memcpy(buffer.payload, bytes, buffer.len);
let chars = CharPtr(capacity: bytes.count)
_ = chars.initialize(from: bytes)

let sPtr = StrPtr(chars: chars)

print(sPtr.pointee)

let objPtr = unsafeUpcast(sPtr)
print(objPtr)
let str2 = objPtr.asStr()
print(str2)
print(str2.pointee)
print(str2.pointee.chars)
print(String(bytes: str2.pointee.chars, encoding: .utf8)!)
