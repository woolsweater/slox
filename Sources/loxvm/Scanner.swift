import Foundation

/** State of source scanning for the Lox VM */
class Scanner
{
    /** Text of the source code to be scanned. */
    private let source: Substring
    /** Location of the scanner within the source text. */
    private var currentSourceIndex: Substring.Index
    /** Location of the first character of the item currently being scanned. */
    private var lexemeStartIndex: Substring.Index
    /** Current line in the source text. */
    private var lineNumber: Int

    /** Create a scanner for the given text. */
    init(source: String)
    {
        self.source = source[...]
        self.currentSourceIndex = self.source.startIndex
        self.lexemeStartIndex = self.source.startIndex
        self.lineNumber = 1
    }
}

extension Scanner
{
    /** Text of the lexical item currently being scanned. */
    private var currentLexeme: Substring
    {
        return self.source[self.lexemeStartIndex..<self.currentSourceIndex]
    }

    /** Whether the scanner has reached the end of the source text. */
    private var hasMoreToScan: Bool
    {
        return self.currentSourceIndex < self.source.endIndex
    }

    /**
     Inspect the source text at the current scan location and produce the appropriate `Token`.
     - remark: This may result in an error token if there is a problem scanning.
     */
    func scanToken() -> Token
    {
        self.skipWhitespaceAndComments()
        self.lexemeStartIndex = self.currentSourceIndex

        guard self.hasMoreToScan else {
            return self.makeToken(ofKind: .EOF)
        }

        let char = self.readNext()

        if char == "\"" {
            return self.readString()    // May return error token
        }
        else if char.isDigit {
            return self.readNumber()
        }
        else if char.canStartIdentifier {
            return self.readIdentifier()
        }

        let nextKind: Token.Kind
        switch char {
            case "(": nextKind = .leftParen
            case ")": nextKind = .rightParen
            case "{": nextKind = .leftBrace
            case "}": nextKind = .rightBrace
            case ";": nextKind = .semicolon
            case ",": nextKind = .comma
            case ".": nextKind = .dot
            case "-": nextKind = .minus
            case "+": nextKind = .plus
            case "/": nextKind = .slash
            case "*": nextKind = .star
            case "!": nextKind = (self.readMatch("=") ? .bangEqual : .bang)
            case "=": nextKind = (self.readMatch("=") ? .equalEqual : .equal)
            case "<": nextKind = (self.readMatch("=") ? .lessEqual : .less)
            case ">": nextKind = (self.readMatch("=") ? .greaterEqual : .greater)
            default:
                return self.makeErrorToken("Unexpected character.")
        }

        return self.makeToken(ofKind: nextKind)
    }

    /**
     Process the source from the current location, moving past any whitespace and line or block
     comments. Advance the `lineNumber` count as necessary. Upon return, the current scan
     location will be at the next semantically significant character.
     */
    private func skipWhitespaceAndComments()
    {
        while let char = self.peek() {
            switch char {
                case "\n":
                    self.lineNumber += 1
                    fallthrough
                case " ", "\r", "\t":
                    self.advanceIndex()
                case "/":
                    let trailing = self.peekAfter()
                    if trailing == "/" {
                        self.skipLineComment()
                    }
                    else if trailing == "*" {
                        self.skipBlockComment()
                    }
                    else {
                        return
                    }
                default:
                    return
            }
        }
    }

    //MARK:- Basic operations

    /**
    Unless the scanner is at the end of the source, produce the next character to be scanned
    without advancing the index.
    */
    private func peek() -> Character?
    {
        guard self.hasMoreToScan else { return nil }
        return self.source[self.currentSourceIndex]
    }

    /**
     Unless the scanner is at or past the penultimate source character, produce the character
     after the next character to be scanned, without advancing the index.
     */
    private func peekAfter() -> Character?
    {
        let nextIndex = self.source.index(after: self.currentSourceIndex)
        guard nextIndex < self.source.endIndex else { return nil }
        return self.source[nextIndex]
    }

    /** Return the next character in the source, advancing the index. */
    private func readNext() -> Character
    {
        defer { self.advanceIndex() }
        return self.source[self.currentSourceIndex]
    }

    /** Advance the index if the next character to be scanned matches the given character. */
    private func readMatch(_ char: Character) -> Bool
    {
        guard self.hasMoreToScan else { return false }
        guard self.source[self.currentSourceIndex] == char else {
            return false
        }

        self.advanceIndex()
        return true
    }

    private func advanceIndex()
    {
        self.currentSourceIndex = self.source.index(after: self.currentSourceIndex)
    }

    //MARK:- Scanning specific types

    /**
     Scan past and discard characters until the end of the line (or the entire source,
     whichever comes first).
     - precondition: The scan position should be at the opening `//` of the comment.
     */
    private func skipLineComment()
    {
        precondition(self.readMatch("/"))
        precondition(self.readMatch("/"))

        while let char = self.peek(), char != "\n" {
            self.advanceIndex()
        }
    }

    /**
     Scan past and discard characters in a block comment, until the closing delimiter (or the
     end of the source, whichever comes first).
     - precondition: The scan position should be at the opening delimiter of the comment.
     - remark: Any block comment opening delimiters within the comment are simply ignored;
     nested comments are not allowed.
     */
    private func skipBlockComment()
    {
        precondition(self.readMatch("/"))
        precondition(self.readMatch("*"))

        while let char = self.peek() {
            self.advanceIndex()
            if char == "*" && self.readMatch("/") {
                return
            }
            else if char == "\n" {
                self.lineNumber += 1
            }
        }

        return    // Unterminated comment
    }

    /**
     Scan a string literal.
     - precondition: The scan position should be just past the opening quote mark of the string.
     - returns: A `Token` for the string, or an error `Token` if the end of the file was
     reached before a closing quote mark.
     */
    private func readString() -> Token
    {
        while let char = self.peek(), char != "\"" {
            if char == "\n" {
                self.lineNumber += 1
            }
            self.advanceIndex()
        }

        guard self.hasMoreToScan else {
            return self.makeErrorToken("Unterminated string")
        }

        self.advanceIndex()
        return self.makeToken(ofKind: .string)
    }

    private func readNumber() -> Token
    {
        self.consumeDigits()

        if self.peek() == "." && self.peekAfter()?.isDigit == true {
            self.advanceIndex()
            self.consumeDigits()
        }

        return self.makeToken(ofKind: .number)
    }

    private func consumeDigits()
    {
        while self.peek()?.isDigit == true {
            self.advanceIndex()
        }
    }

    private func readIdentifier() -> Token
    {
        while let char = self.peek() {
            guard char.isDigit || char.isLegalIdentifier else {
                break
            }
            self.advanceIndex()
        }

        return self.makeToken(ofKind: self.currentIdentifierKind())
    }

    /**
     Determine whether the current lexeme is a language keyword or a user-specified identifier,
     returning the appropriate `Token.Kind`.
     */
    private func currentIdentifierKind() -> Token.Kind
    {
        switch self.currentLexeme.first! {
            case "a": return self.checkForKeyword(at: 1, rest: "nd", kind: .and)
            case "c": return self.checkForKeyword(at: 1, rest: "lass", kind: .class)
            case "e": return self.checkForKeyword(at: 1, rest: "lse", kind: .else)
            case "f":
                guard self.currentLexeme.count > 2 else { break }
                switch self.source[self.source.index(after: self.lexemeStartIndex)] {
                    case "a": return self.checkForKeyword(at: 2, rest: "lse", kind: .false)
                    case "o": return self.checkForKeyword(at: 2, rest: "r", kind: .for)
                    case "u": return self.checkForKeyword(at: 2, rest: "n", kind: .fun)
                    default: break
                }
                break
            case "i": return self.checkForKeyword(at: 1, rest: "f", kind: .if)
            case "n": return self.checkForKeyword(at: 1, rest: "il", kind: .nil)
            case "o": return self.checkForKeyword(at: 1, rest: "r", kind: .or)
            case "p": return self.checkForKeyword(at: 1, rest: "rint", kind: .print)
            case "r": return self.checkForKeyword(at: 1, rest: "eturn", kind: .return)
            case "s": return self.checkForKeyword(at: 1, rest: "uper", kind: .super)
            case "t":
                guard self.currentLexeme.count > 3 else { break }
                switch self.source[self.source.index(after: self.lexemeStartIndex)] {
                    case "h": return self.checkForKeyword(at: 2, rest: "is", kind: .this)
                    case "r": return self.checkForKeyword(at: 2, rest: "ue", kind: .true)
                    default: break
                }
                break
            case "u":
                guard
                    self.currentLexeme.count > 4 &&
                    self.source[self.source.index(after: self.lexemeStartIndex)] == "n"
                else { break }
                switch self.source[self.source.index(self.lexemeStartIndex, offsetBy: 2)] {
                    case "l": return self.checkForKeyword(at: 3, rest: "less", kind: .unless)
                    case "t": return self.checkForKeyword(at: 3, rest: "til", kind: .until)
                    default: break
                }
                break
            case "v": return self.checkForKeyword(at: 1, rest: "ar", kind: .var)
            case "w": return self.checkForKeyword(at: 1, rest: "hile", kind: .while)
            default:
                break
        }

        return .identifier
    }

    private func checkForKeyword(at offset: Int,
                                      rest: String,
                                      kind: Token.Kind)
        -> Token.Kind
    {
        if self.currentLexeme.count == offset + rest.count {
            let trailingStart = self.source.index(self.lexemeStartIndex, offsetBy: offset)
            let trailing = self.source[trailingStart..<self.currentSourceIndex]
            if trailing == rest {
                return kind
            }
        }

        return .identifier
    }

    //MARK:- Creating tokens

    /**
     Create a token representing the most recently scanned lexeme, which has now been identified
     as being of the given `Kind`.
     */
    private func makeToken(ofKind kind: Token.Kind) -> Token
    {
        return Token(kind: kind,
                   lexeme: self.currentLexeme,
               lineNumber: self.lineNumber)
    }

    private func makeErrorToken(_ message: String) -> Token
    {
        return Token(kind: .error, lexeme: message[...], lineNumber: self.lineNumber)
    }
}

//MARK:- Character helpers

private extension CharacterSet
{
    static let loxIdentifiers =
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
}

private extension Character
{

    var isLegalIdentifier: Bool
    {
        return self.canStartIdentifier || self.isDigit
    }

    var isDigit: Bool { return "0"..."9" ~= self }

    var canStartIdentifier: Bool
    {
        guard self.unicodeScalars.count == 1 else { return false }
        if self.isDigit { return false }
        return CharacterSet.loxIdentifiers.contains(self.unicodeScalars.first!)
    }
}
