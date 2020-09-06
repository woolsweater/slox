import Foundation

/** String processing for the Lox `Compiler` */
class StringCompiler
{
    private let allocator: MemoryManager

    /**
     Create a `StringCompiler` that will use the given `MemoryManager` to
     acquire whatever memory it needs for processing.
     */
    init(allocator: MemoryManager)
    {
        self.allocator = allocator
    }
}

extension StringCompiler
{
    /**
     Recognize and process valid escape sequences into their corresponding UTF-8
     encoding, then invoke `body` with a buffer containing the full encoded contents.
     The data must be copied by `body`; the pointer will become invalid immediately after.
     - throws: A `StringEscapeError` describing a problem that was found while parsing an
     escape sequence.
     - returns: The result of `body`
     - remark: Anything in the original string that is not part of an escape sequence
     is copied straight over.
     */
    func withRenderedEscapes<T>(in s: Substring, _ body: (ConstCStr) -> T) throws -> T
    {
        let processed = try s.withCString(encodedAs: UTF8.self,
                                          self.processString)
        defer { self.allocator.destroyBuffer(processed.base) }
        return body(UnsafeBufferPointer(rebasing: processed))
    }

    // Annoying inconsistency in Swift here: `CChar = Int8` but `withCString(encodedAs:_:)`
    // and `Character.asciiValue` both provide `UInt8`. We therefore work internally with
    // `UInt8` and then convert right before passing the results out to the code that needs
    // to work with the C struct.
    private func processString(_ contents: UnsafePointer<UInt8>) throws -> Slice<CStr>
    {
        let count = contents.cStringLength()

        let result = self.allocator.allocateBuffer(of: UInt8.self, count: count + 1)
        var currentDest = result.baseAddress!

        var currentSource = contents
        while let nextEscape = currentSource.find(ASCII.slash) {
            let escapeChar = nextEscape + 1
            if let encoded = encodeSimpleEscape(escapeChar.pointee) {
                currentDest.appendContents(of: currentSource, through: nextEscape)
                currentDest.pointee = encoded
                currentDest += 1
                currentSource = escapeChar + 1
                continue
            }

            guard escapeChar.pointee == ASCII.lowerU else {
                //FIXME: "codeUnit" -- This byte could be part of a multibyte sequence
                throw UnrecognizedEscape(codeUnit: escapeChar.pointee)
            }

            let digitStart = escapeChar + 1
            let (codepoint, digitEnd) = try parseHexEscape(digitStart)
            guard digitEnd.pointee == ASCII.semicolon else {
                //FIXME: "codeUnit" -- This byte could be part of a multibyte sequence
                throw UnterminatedUnicode(codeUnit: digitEnd.pointee)
            }

            let (encoded, encodedLength) = try codepoint.toUTF8()

            currentDest.appendContents(of: currentSource, through: nextEscape)
            _ = withUnsafePointer(to: encoded) {
                memcpy(currentDest, UnsafeRawPointer($0), encodedLength)
                currentDest += encodedLength
            }
            currentSource = digitEnd + 1    // Step over terminator
        }

        currentDest.appendContents(of: currentSource, through: contents + count)
        currentDest.pointee = 0x0

        let filledLength = currentDest - result.baseAddress!
        return UnsafeMutableRawBufferPointer(result).bindMemory(to: CChar.self)[...filledLength]
    }
}

/**
 ASCII encoding values for various characters that we need
 to be able to handle.
 */
private enum ASCII
{
    static let lowerN = Character("n").asciiValue!
    static let lowerR = Character("r").asciiValue!
    static let lowerT = Character("t").asciiValue!
    static let lowerU = Character("u").asciiValue!
    static let slash = Character(#"\"#).asciiValue!
    static let doubleQuote = Character("\"").asciiValue!
    static let semicolon = Character(";").asciiValue!

    static let newline = Character("\n").asciiValue!
    static let carriageReturn = Character("\r").asciiValue!
    static let tab = Character("\t").asciiValue!

    static func isHexDigit(_ char: UInt8) -> Bool
    {
        return char.asciiHexDigitValue != nil
    }
}

/**
 Encode the given value as the leading byte of a UTF-8 sequence
 of the given length.
 - remark: The encoding takes only the low `8 - sequenceCount - 1`
 bits from the input, then sets the top `sequenceCount` bits.
 (The high bits indicate the length of the sequence; they are always
 followed by a single 0 bit; the lowest bits then contain the "payload".)
 A codepoint <= 255 is encoded directly as a single `UInt8`.
 */
@inline(__always)
private func utf8LeadingByte(_ value: UInt32, sequenceCount: Int) -> UInt32
{
    switch sequenceCount {
        case 2:
            return (value & 0b1_1111) | 0b1100_0000
        case 3:
            return (value & 0b1111) | 0b1110_0000
        case 4:
            return (value & 0b0111) | 0b1111_0000
        default:
            fatalError("Illegal byte count")
    }
}

/**
 Encode the given value as one of the bytes in position 2-4
 of a UTF-8 sequence.
 - remark: The encoding takes the low 6 bits from the input,
 then sets the top bit and unsets the second from the top.
 */
@inline(__always)
private func utf8TrailingByte(_ value: UInt32) -> UInt32
{
    (value & 0b11_1111) | 0b1000_0000
}

/**
 Parse up to 6 ASCII hexadecimal digit characters
 into the corresponding codepoint.
 - throws: `UnicodeInitialNonHex` if the first character of the
 sequence is not a hexadecimal digit
 - returns: If the sequence is valid, returns the parsed value and a
 pointer to the character following the last parsed digit.
 */
private func parseHexEscape(_ start: UnsafePointer<UInt8>) throws -> (UInt32, end: UnsafePointer<UInt8>)
{
    guard ASCII.isHexDigit(start.pointee) else {
        //FIXME: "codeUnit" -- This byte could be part of a multibyte sequence
        throw UnicodeInitialNonHex(codeUnit: start.pointee)
    }

    var codepoint: UInt32 = 0
    var current = start
    // The highest valid codepoint is U+10FFFF, six hexadecimal digits
    while let value = current.pointee.asciiHexDigitValue, start.distance(to: current) <= 6 {
        codepoint <<= 4
        codepoint += UInt32(value)
        current += 1
    }

    return (codepoint, current)
}

/**
 If the byte represents one of our recognized escape
 characters, return the UTF-8 encoding of the sequence;
 otherwise return `nil`.
 */
private func encodeSimpleEscape(_ char: UInt8) -> UInt8?
{
    switch char {
        case ASCII.lowerN:
            return ASCII.newline
        case ASCII.lowerR:
            return ASCII.carriageReturn
        case ASCII.lowerT:
            return ASCII.tab
        case ASCII.doubleQuote:
            return ASCII.doubleQuote
        case ASCII.slash:
            return ASCII.slash
        default:
            return nil
    }
}

private extension UnsafePointer where Pointee == UInt8
{
    /**
     Walk this C string to find the given byte.
     - returns: A pointer to the first instance of the
     given byte in the string, or `nil` if the byte
     was not found (a `NUL` byte was found first).
     - warning: If this pointer is not a proper C string
     (there is no terminating `NUL`), and the sought byte
     is not present, this has undefined behavior.
     - remark: Analogous to `strchr` in the C stdlib.
     */
    @inline(__always)
    func find(_ char: UInt8) -> UnsafePointer<UInt8>?
    {
        var pointer = self
        while pointer.pointee != char {
            if pointer.pointee == 0x0 {
                return nil
            }
            pointer = pointer.successor()
        }
        return pointer
    }

    /**
     Find the length of this C string.
     - warning: If this pointer is not a proper C string
     (there is no terminating `NUL`), this has undefined
     behavior.
     - remark: Analagous to `strlen` from the C stdlib.
     */
    @inline(__always)
    func cStringLength() -> Int
    {
        return self.find(0x0)! - self
    }
}

private extension UnsafeMutablePointer where Pointee == UInt8
{
    /**
     Copy the contents of the region from `start` through `end` into
     `self`, then advance `self` by the number of bytes copied.
     - important:
        - `self` must point to an allocation big enough to hold the new
     bytes
        - `end` must be a location higher than `start`, in the
     same block of memory
     Behavior is undefined if either of these conditions do not hold.
     */
    mutating func appendContents(of start: UnsafePointer<UInt8>, through end: UnsafePointer<UInt8>)
    {
        precondition(end >= start, "Cannot copy region of negative size")
        let count = end - start
        self.assign(from: start, count: count)
        self += count
    }
}

private extension BinaryInteger
{
    /**
     The numerical value of the ASCII hexadecimal digit
     encoded by this number. `nil` if this number is not
     the ASCII encoding of a hexadecimal digit.
     - remark: Uppercase and lowercase ASCII are supported.
     - example: 67 is the ASCII encoding for the letter 'C',
     whose value as a hexadecimal digit is 12.
     */
    var asciiHexDigitValue: Self?
    {
        switch self {
            // 0-9
            case 48...57:
                return self - 48
            // A-F
            case 65...70:
                return (self - 65) + 0xa
            // a-f
            case 97...102:
                return (self - 97) + 0xa
            default:
                return nil
        }
    }
}

private extension UInt32
{
    /**
     Transform this value, which must be a valid Unicode codepoint, into
     its UTF-8 encoding.
     - throws: `InvalidCodepoint` if the original value is beyond 0x10ffff
     or is one of the UTF-16 surrogate pair codepoints.
     - returns: The UTF-8 code units, packed into a `UInt32` such that
     the leading byte is _physically_ the first byte (big-endian, in a sense);
     trailing bytes follow and unused bytes are 0. The length of the UTF-8
     sequence (the number of used bytes) is returned alongside.
     */
    func toUTF8() throws -> (UInt32, Int)
    {
        var contents: UInt32 = 0
        let length: Int
        if self < 0x80 {
            length = 1
            contents = self
        }
        else if self < 0x800 {
            length = 2
            contents =
                utf8LeadingByte(self >> 6, sequenceCount: length) << 8 |
                utf8TrailingByte(self)
        }
        else if self < 0x1_0000 {
            if self.isUTF16Surrogate {
                throw InvalidCodepoint(codepoint: self, reason: .surrogate)
            }

            length = 3
            contents =
                utf8LeadingByte(self >> 12, sequenceCount: length) << 16 |
                (utf8TrailingByte(self >> 6) << 8) |
                utf8TrailingByte(self)
        }
        else if self <= 0x10ffff  {
            length = 4
            contents =
                utf8LeadingByte(self >> 18, sequenceCount: length) << 24 |
                (utf8TrailingByte(self >> 12) << 16) |
                (utf8TrailingByte(self >> 6) << 8) |
                utf8TrailingByte(self)
        }
        else {
            throw InvalidCodepoint(codepoint: self, reason: .outOfRange)
        }

        // Slide code units so that the leading one is in the MSB
        contents <<= (4 - length) * 8
        // Ensure leading code unit is physically first for memcpy'ing
        return (contents.bigEndian, length)
    }

    /**
     Whether this is a surrogate codepoint (for UTF-16). Such codepoints
     are ruled illegal in Lox Unicode escapes, for simplicity.
     */
    private var isUTF16Surrogate: Bool
    {
        switch self {
            case 0xd800...0xdbff: return true
            case 0xdc00...0xdfff: return true
            default: return false
        }
    }
}
