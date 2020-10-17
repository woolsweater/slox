import Foundation

// Miscellaneous functionality for the Lox VM

/**
 Calculate the "FNV-1a" hash of the bytes in the string.
 - parameter base: Pointer to the initial byte
 - parameter stringLength: The count of bytes _excluding_ the terminal NUL.
 - returns: The hash calculated from all the bytes in the string.
 - remark: The NUL will be included in the calculation of the hash.
 */
func loxHash(_ base: UnsafeMutablePointer<CChar>, stringLength: Int) -> UInt32
{
    return UnsafeBufferPointer(start: base, count: stringLength + 1) |> loxHash(_:)
}

/**
 Calculate the "FNV-1a" hash of the bytes in the string.
 - parameter chars: The byte buffer for the string.
 - returns: The hash calculated from all the bytes in the string.
 - remark: The NUL will be included in the calculation of the hash.
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
