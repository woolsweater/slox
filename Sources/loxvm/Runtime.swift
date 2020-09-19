import Foundation

// Miscellaneous functionality for the Lox VM

/**
 Calculate and store the "FNV-1a" hash of the characters in the string
 */
func loxHash(_ base: UnsafeMutablePointer<CChar>, length: Int) -> UInt32
{
    return UnsafeBufferPointer(start: base, count: length) |> loxHash(_:)
}

/**
 Calculate and store the "FNV-1a" hash of the characters in the string
 */
func loxHash(_ chars: ConstCStr) -> UInt32
{
    var hash: UInt32 = 2166136261

    for byte in chars {
        let paddedByte = byte |> UInt8.init(bitPattern:) |> UInt32.init(_:)
        hash ^= paddedByte
        hash &*= 16777619
    }

    return hash
}
