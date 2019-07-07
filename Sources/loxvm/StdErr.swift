import Foundation

/** Wrapper for output to stderr. */
struct StdErr
{
    /** Write the string to stderr, appending a newline. */
    static func print(_ string: String)
    {
        let description = string + "\n"
        let data = description.data(using: .utf8)!
        FileHandle.standardError.write(data)
    }
}
