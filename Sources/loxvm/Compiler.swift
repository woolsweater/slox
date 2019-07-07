import Foundation

/**
 Translator from a token stream to bytecode stored in a `Chunk`, using a `Scanner` as a helper
 to get tokens from the provided source.
 */
class Compiler
{
    private let scanner: Scanner

    /** Create a compiler to operate on the given source. */
    init(source: String)
    {
        self.scanner = Scanner(source: source)
    }

    /** Translate the source into bytecode. */
    func compile() -> Chunk
    {
        var currentLine = -1
        while true {
            let token = self.scanner.scanToken()

            guard token.kind != .EOF else { break }

            if token.lineNumber != currentLine {
                currentLine = token.lineNumber
                print(String(format: "%04d :", currentLine), terminator: "")
            }
            else {
                print("   | :", terminator: "")
            }

            print("\(token.kind) '\(token.lexeme)'")
        }

        return Chunk()
    }
}
