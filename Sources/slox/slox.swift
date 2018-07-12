import Foundation

func main(_ args: [String]) -> Int32
{
    let args = Array(args.dropFirst())

    guard args.count <= 1 else {
        return ExitCode.badUsage.returnValue
    }

    if let path = args.first {
        do { try runFile(path) }
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
}

private func runPrompt()
{
    printPrompt()
    while let line = readLine() {
        run(line)
        printPrompt()
    }
}

private func run(_ source: String)
{
    let scanner = Scanner(string: source)
    let tokens = scanner.scanTokens()

    for token in tokens {
        print(token)
    }
}

private extension Scanner
{
    func scanTokens() -> [String]
    {
        return self.string.components(separatedBy: .whitespaces)
    }
}

private func printPrompt()
{
    print("> ", terminator: "")
}
