import Foundation

/** State of source scanning for the Lox VM */
class VMScanner
{
    private let source: Substring
    private var currentSourceIndex: Substring.Index
    private var lexemeStartIndex: Substring.Index
    private var lineNumber: Int

    init(source: String)
    {
        self.source = source[...]
        self.currentSourceIndex = self.source.startIndex
        self.lexemeStartIndex = self.source.startIndex
        self.lineNumber = 1
    }
}

struct Token
{
    let kind: Token.Kind
    let lexeme: Substring
    let lineNumber: Int
}

extension Token
{
    /**
     The basic role of a `Token`, including specific punctuation, keywords,
     operators, and so on.
     */
    enum Kind : Equatable
    {
        // Single-character punctuation
        case leftParen, rightParen, leftBrace, rightBrace
        case comma, dot, semicolon
        case minus, plus, slash, star

        // Single- and double-character punctuation
        case bang, bangEqual, equal, equalEqual
        case greater, greaterEqual, less, lessEqual

        // Literals
        case identifier, string, number

        // Keywords
        case and, `break`, `class`, `else`, `false`, fun, `for`, `if`, `nil`, or
        case print, `return`, `super`, this, `true`, unless, until, `var`, `while`

        case EOF

        case error
    }
}

extension VMScanner
{
    private var currentLexeme: Substring
    {
        return self.source[self.lexemeStartIndex..<self.currentSourceIndex]
    }

    private var hasMoreToScan: Bool
    {
        return self.currentSourceIndex < self.source.endIndex
    }

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

    private func peek() -> Character?
    {
        guard self.hasMoreToScan else { return nil }
        return self.source[self.currentSourceIndex]
    }

    private func peekAfter() -> Character?
    {
        let nextIndex = self.source.index(after: self.currentSourceIndex)
        guard nextIndex < self.source.endIndex else { return nil }
        return self.source[nextIndex]
    }

    private func readNext() -> Character
    {
        defer { self.advanceIndex() }
        return self.source[self.currentSourceIndex]
    }

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

    private func skipLineComment()
    {
        while let char = self.peek(), char != "\n" {
            self.advanceIndex()
        }
    }

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

    private func currentIdentifierKind() -> Token.Kind
    {
        switch self.currentLexeme.first! {
            case "a": return self.checkForKeyword(at: 1, length: 2, rest: "nd", kind: .and)
            case "c": return self.checkForKeyword(at: 1, length: 4, rest: "lass", kind: .class)
            case "e": return self.checkForKeyword(at: 1, length: 3, rest: "lse", kind: .else)
            case "f":
                guard self.currentLexeme.count > 2 else { break }
                switch self.source[self.source.index(after: self.lexemeStartIndex)] {
                    case "a": return self.checkForKeyword(at: 2, length: 3, rest: "lse", kind: .false)
                    case "o": return self.checkForKeyword(at: 2, length: 1, rest: "r", kind: .for)
                    case "u": return self.checkForKeyword(at: 2, length: 1, rest: "n", kind: .fun)
                    default: break
                }
                break
            case "i": return self.checkForKeyword(at: 1, length: 1, rest: "f", kind: .if)
            case "n": return self.checkForKeyword(at: 1, length: 2, rest: "il", kind: .nil)
            case "o": return self.checkForKeyword(at: 1, length: 1, rest: "r", kind: .or)
            case "p": return self.checkForKeyword(at: 1, length: 4, rest: "rint", kind: .print)
            case "r": return self.checkForKeyword(at: 1, length: 5, rest: "eturn", kind: .return)
            case "s": return self.checkForKeyword(at: 1, length: 4, rest: "uper", kind: .super)
            case "t":
                guard self.currentLexeme.count > 3 else { break }
                switch self.source[self.source.index(after: self.lexemeStartIndex)] {
                    case "h": return self.checkForKeyword(at: 2, length: 2, rest: "is", kind: .this)
                    case "r": return self.checkForKeyword(at: 2, length: 2, rest: "ue", kind: .true)
                    default: break
                }
                break
            case "u":
                guard
                    self.currentLexeme.count > 4 &&
                    self.source[self.source.index(after: self.lexemeStartIndex)] == "n"
                else { break }
                switch self.source[self.source.index(self.lexemeStartIndex, offsetBy: 2)] {
                    case "l": return self.checkForKeyword(at: 3, length: 4, rest: "less", kind: .unless)
                    case "t": return self.checkForKeyword(at: 3, length: 3, rest: "til", kind: .until)
                    default: break
                }
                break
            case "v": return self.checkForKeyword(at: 1, length: 2, rest: "ar", kind: .var)
            case "w": return self.checkForKeyword(at: 1, length: 4, rest: "hile", kind: .while)
            default:
                break
        }

        return .identifier
    }

    private func checkForKeyword(at offset: Int,
                                    length: Int,
                                      rest: String,
                                      kind: Token.Kind)
        -> Token.Kind
    {
        if self.currentLexeme.count == offset + length {
            let trailingStart = self.source.index(self.lexemeStartIndex, offsetBy: offset)
            let trailing = self.source[trailingStart..<self.currentSourceIndex]
            if trailing == rest {
                return kind
            }
        }

        return .identifier
    }

    //MARK:- Creating tokens

    private func makeToken(ofKind kind: Token.Kind) -> Token
    {
        let lexeme = self.source[self.lexemeStartIndex..<self.currentSourceIndex]
        return Token(kind: kind,
                   lexeme: lexeme,
               lineNumber: self.lineNumber)
    }

    private func makeErrorToken(_ message: String) -> Token
    {
        return Token(kind: .error, lexeme: message[...], lineNumber: self.lineNumber)
    }
}


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
        return CharacterSet.loxIdentifiers.contains(self.unicodeScalars.first!)
    }
}
