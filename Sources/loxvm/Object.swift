import loxvm_object

typealias CharPtr = UnsafeMutableBufferPointer<UInt8>

extension ObjectString {
    init(chars: CharPtr) {
        assert(chars.baseAddress != nil)
        self.init(header: Object(kind: .string),
                  length: chars.count,
                   chars: chars.baseAddress!)
    }
}

extension StringRef {
    init(chars: CharPtr) {
        let p = UnsafeMutablePointer<ObjectString>.allocate(capacity: 1)
        p.initialize(to: ObjectString(chars: chars))
        self.init(p)
    }
}
