import Foundation

func ~=<T>(predicate: (T) -> Bool, value: T) -> Bool
{
    return predicate(value)
}

class LoxScanner
{
    var isAtEnd: Bool
    {
        return self.currentSourceIndex >= self.source.endIndex
    }

    private var currentLexeme: String
    {
        return String(self.source[self.lexemeStartIndex..<self.currentSourceIndex])
    }

    private var currentSourceIndex: String.Index

    private var lexemeStartIndex: String.Index
    private var lineNumber: Int = 1

    private let source: String
    private var tokens: [Token] = []

    init(source: String)
    {
        self.source = source
        self.currentSourceIndex = source.startIndex
        self.lexemeStartIndex = source.startIndex
    }

    func scanTokens() -> [Token]
    {
        while !self.isAtEnd {
            self.lexemeStartIndex = self.currentSourceIndex
            self.scanToken()
        }

        self.tokens.append(Token.eof(self.lineNumber))
        return self.tokens
    }

    private func scanToken()
    {
        let char = self.readNext()
        switch char {
            case "(": self.addToken(.leftParen)
            case ")": self.addToken(.rightParen)
            case "{": self.addToken(.leftBrace)
            case "}": self.addToken(.rightBrace)
            case ",": self.addToken(.comma)
            case ".": self.addToken(.dot)
            case "-": self.addToken(.minus)
            case "+": self.addToken(.plus)
            case ";": self.addToken(.semicolon)
            case "*": self.addToken(.star)
            case "!": self.addToken(self.readMatch("=") ? .bangEqual : .bang)
            case "=": self.addToken(self.readMatch("=") ? .equalEqual : .equal)
            case "<": self.addToken(self.readMatch("=") ? .lessEqual : .less)
            case ">": self.addToken(self.readMatch("=") ? .greaterEqual : .greater)
            case "/":
                if self.readMatch("/") {
                    while self.peek() != "\n" && !(self.isAtEnd) {
                        self.advanceIndex()
                    }
                }
                else {
                    self.addToken(.slash)
                }
            case " ", "\r", "\t": break
            case "\n": self.lineNumber += 1
            case "\"": self.readString()
            case isDigit: self.readNumber()
            case canStartIdentifier: self.readIdentifier()
            default:
                reportError(at: self.lineNumber,
                            message: "Unexpected character: \(char)")
        }
    }

    private func readNext() -> Character
    {
        defer { self.advanceIndex() }
        return self.source[self.currentSourceIndex]
    }

    private func peek() -> Character
    {
        guard !(self.isAtEnd) else { return "\0" }
        return self.source[self.currentSourceIndex]
    }

    private func peekAfter() -> Character
    {
        let nextIndex =
            self.source.index(after: self.currentSourceIndex)
        guard nextIndex <= self.source.endIndex else { return "\0" }
        return self.source[nextIndex]
    }

    private func readString()
    {
        while self.peek() != "\"" && !(self.isAtEnd) {
            if self.peek() == "\n" { self.lineNumber += 1 }
            self.advanceIndex()
        }

        guard !(self.isAtEnd) else {
            reportError(at: self.lineNumber,
                   message: "Unterminated string")
            return
        }

        let stringContent = self.currentLexeme.dropFirst()
        // Include closing " in lexeme, but not contents
        self.advanceIndex()
        self.addToken(.string, literal: stringContent)
    }

    private func readNumber()
    {
        while isDigit(self.peek()) {
            self.advanceIndex()
        }

        if self.peek() == "." && isDigit(self.peekAfter()) {
            self.advanceIndex()
            while isDigit(self.peek()) {
                self.advanceIndex()
            }
        }

        self.addToken(.number, literal: Double(self.currentLexeme)!)
    }

    private func readIdentifier()
    {
        while self.peek().isLegalIdentifier {
            self.advanceIndex()
        }

        let kind = Token.Kind(keyword: self.currentLexeme) ?? .identifier
        self.addToken(kind)
    }

    private func addToken(_ kind: Token.Kind, literal: Any? = nil)
    {
        let newToken = Token(kind: kind,
                           lexeme: self.currentLexeme,
                          literal: literal,
                             line: self.lineNumber)
        self.tokens.append(newToken)
    }

    private func readMatch(_ char: Character) -> Bool
    {
        guard !(self.isAtEnd) else { return false }
        guard self.source[self.currentSourceIndex] == char else {
            return false
        }

        self.advanceIndex()
        return true
    }

    private func advanceIndex()
    {
        self.currentSourceIndex =
            self.source.index(after: self.currentSourceIndex)
    }
}

private func isDigit(_ char: Character) -> Bool
{
    return char.isDigit
}

private func canStartIdentifier(_ char: Character) -> Bool
{
    return char.canStartIdentifier
}

extension CharacterSet
{
    static let loxIdentifiers =
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
}

extension Character
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
