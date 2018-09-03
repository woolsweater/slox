import Foundation

/**
 Checks for problems in control statements, such as misplaced `return`s
 or `breaks`, reporting them as errors.
 */
class ControlStatementAnalyzer : SemanticAnalyzer
{
    /**
     Track levels of looping so that a `break` statment outside any
     loop can be reported as an error.
     */
    private var loopState = NestingCounter()

    /**
     Track levels of function declarations so that a `return`
     statement outside a function can be reported as an error.
     */
    private var funcState = NestingCounter()

    func analyze(_ statement: Statement) throws
    {
        switch statement {
            case let .functionDecl(identifier: _, parameters: _, body: body):
                try self.analyzeFunction(body)
            case let .return(token, value: _):
                try self.analyzeReturn(at: token)
            case let .breakLoop(token):
                try self.analyzeBreak(token)
            default:
                return
        }
    }

    private func analyzeFunction(_ body: [Statement]) throws
    {
        self.funcState++
        defer { self.funcState-- }

        for statement in body {
            try self.analyze(statement)
        }
    }

    private func analyzeReturn(at token: Token) throws
    {
        guard self.funcState.isNested else {
            throw SemanticError.misplacedReturn(at: token)
        }
    }

    private func analyzeBreak(_ token: Token) throws
    {
        guard self.loopState.isNested else {
            throw SemanticError.misplacedBreak(at: token)
        }
    }
}

private extension SemanticError
{
    static func misplacedReturn(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Cannot return outside a function")
    }

    static func misplacedBreak(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Cannot break outside a loop")
    }
}
