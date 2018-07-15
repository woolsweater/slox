import Foundation

func main(_ args: [String]) -> Int32
{
    let args = Array(args.dropFirst())

    guard args.count <= 1 else {
        return ExitCode.badUsage.returnValue
    }

    if let path = args.first {
        do { try runFile(path) }
        catch LoxError.interpretation { return ExitCode.interpreterFailure.returnValue }
        catch { return ExitCode.badInput.returnValue }
    }
    else {
        runPrompt()
    }

    return 0
}

private func runFile(_ path: String) throws
{
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    run(contents)
    if hasError {
        throw LoxError.interpretation
    }
}

private func runPrompt()
{
    printPrompt()
    while let line = readLine() {
        run(line)
        hasError = false
        printPrompt()
    }
}

private func run(_ source: String)
{
    let scanner = LoxScanner(source: source)
    let tokens = scanner.scanTokens()

    for token in tokens {
        print(token)
    }
}

private func printPrompt()
{
    print("> ", terminator: "")
}

var hasError = false

func reportError(at line: Int, message: String)
{
    report(at: line, location: "", message: message)
}

private func report(at line: Int, location: String, message: String)
{
    print("[line \(line)] Error \(location): \(message)")
    hasError = true
}

enum LoxError : Error
{
    case interpretation
}
