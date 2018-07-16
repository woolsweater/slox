import Foundation

class Lox
{
    static private(set) var hasError = false

    static func main(_ args: [String]) -> Int32
    {
        let args = Array(args.dropFirst())

        guard args.count <= 1 else {
            return ExitCode.badUsage.returnValue
        }

        if let path = args.first {
            do { try self.runFile(path) }
            catch LoxError.interpretation { return ExitCode.interpreterFailure.returnValue }
            catch { return ExitCode.badInput.returnValue }
        }
        else {
            self.runPrompt()
        }

        return 0
    }

    static func report(at line: Int, location: String, message: String)
    {
        print("[line \(line)] Error \(location): \(message)")
        hasError = true
    }

    private enum LoxError : Error
    {
        case interpretation
    }

    private static func runFile(_ path: String) throws
    {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        self.run(contents)
        if self.hasError {
            throw LoxError.interpretation
        }
    }

    private static func runPrompt()
    {
        self.printPrompt()
        while let line = readLine() {
            self.run(line)
            self.hasError = false
            self.printPrompt()
        }
    }

    private static func run(_ source: String)
    {
        let scanner = LoxScanner(source: source)
        let tokens = scanner.scanTokens()

        let parser = Parser(tokens: tokens)
        guard
            let expr = parser.parse(),
            !self.hasError else
        {
            print("Parsing failed")
            return
        }

        let renderer = AstParenRenderer(ast: expr)
        print(renderer.renderAst())
    }

    private static func printPrompt()
    {
        print("> ", terminator: "")
    }

}
