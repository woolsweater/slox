import Foundation

/** Exit codes from sysexits.h */
enum ExitCode : Int32
{
    /** Incorrect arguments were supplied to the interpreter. */
    case badUsage = 64
    /** The interpreter input could not be parsed. */
    case interpreterFailure = 65
    /** The path passed to the interpreter could not be opened or read. */
    case badInput = 66
}

extension ExitCode
{
    var returnValue: Int32 { return self.rawValue }
}
