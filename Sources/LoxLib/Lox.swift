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

    /**
     Report an error to the user that prevents execution from continuing.
     */
    static func report(at line: Int, location: String, message: String)
    {
        StdErr.print("[line \(line)] Error \(location): \(message)")
        self.hasError = true
    }

    /**
     Emit a warning to the user. This informs the user of a *likely* mistake in
     their code, but does not stop analysis or execution.
     */
    static func warn(at line: Int, location: String, message: String)
    {
        StdErr.print("[line: \(line)] Warning \(location): \(message)")
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
            !(self.hasError)
        else { return }

        let coordinator = AnalysisCoordinator(analyzers:
            KeywordPlacementAnalyzer()
        )

        coordinator.analyze(program)

        guard !(self.hasError) else { return }

        self.interpreter.interpret(program)
    }

    private static func printPrompt()
    {
        print("> ", terminator: "")
    }
}
