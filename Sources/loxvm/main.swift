import Foundation

private func runRepl(using vm: VM)
{
    print("> ", terminator: "")
    while let line = readLine() {
        _ = vm.interpret(source: line)
        print("> ", terminator: "")
    }
}

private func runFile(using vm: VM, path: String) -> ExitCode
{
    guard let source = try? String(contentsOfFile: path) else {
        return .badInput
    }

    let result = vm.interpret(source: source)

    switch result {
        case .compileError: return .interpreterFailure
        case .runtimeError: return .runtimeFailure
        default: return .okay
    }
}

func loxMain(_ args: [String]) -> ExitCode
{
    guard args.count < 3 else {
        StdErr.print("Usage: loxvm [path]")
        return .badUsage
    }

    let vm = VM()

    if args.count == 1 {
        runRepl(using: vm)
        return .okay
    }
    else if args.count == 2 {
        return runFile(using: vm, path: args[1])
    }

    // args.count == 0; unreachable
    return .badInput
}

exit(loxMain(ProcessInfo.processInfo.arguments).returnValue)
