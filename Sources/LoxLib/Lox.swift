import Foundation

public class Lox
{
    private(set) static var hasError = false

    private static var interpreter: Interpreter!

    public static func main(_ args: [String]) -> Int32
    {
        let args = Array(args.dropFirst())

        guard args.count <= 1 else {
            return ExitCode.badUsage.returnValue
        }

        if let path = args.first {
            self.interpreter = Interpreter(replMode: false)
            do { try self.runFile(path) }
            catch ExecError.interpretation { return ExitCode.interpreterFailure.returnValue }
            catch { return ExitCode.badInput.returnValue }
        }
        else {
            self.interpreter = Interpreter(replMode: true)
            self.runPrompt()
        }

        return 0
    }

    static func clearError()
    {
        self.hasError = false
    }

    static func report(at line: Int, location: String, message: String)
    {
        print("[line \(line)] Error \(location): \(message)")
        hasError = true
    }

    private enum ExecError : Error
    {
        case interpretation
    }

    private static func runFile(_ path: String) throws
    {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        self.run(contents)
        if self.hasError {
            throw ExecError.interpretation
        }
    }

    private static func runPrompt()
    {
        self.printPrompt()
        while let line = readLine() {
            self.run(line)
            self.clearError()
            self.printPrompt()
        }
    }

    private static func run(_ source: String)
    {
        let scanner = LoxScanner(source: source)
        let tokens = scanner.scanTokens()

        let parser = Parser(tokens: tokens)
        guard
            let program = parser.parse(),
            !self.hasError else
        {
            print("Parsing failed")
            return
        }

        self.interpreter.interpret(program)
    }

    private static func printPrompt()
    {
        print("> ", terminator: "")
    }
}
