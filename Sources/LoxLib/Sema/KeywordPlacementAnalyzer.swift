import Foundation

/**
 Checks for keywords used in scopes where they are invalid -- such as
 `return`s outside functions or `break`s outside loops -- reporting them
 as errors.
 */
class KeywordPlacementAnalyzer : SemanticAnalyzer
{
    /**
     Track levels of looping so that a `break` statment outside any
     loop can be reported as an error.
     */
    private var loopState = NestingCounter()

    /**
     Track class nesting so that a `this` reference outside a class
     can be reported as an error.
     */
    private var classState = NestingCounter()

    /**
     Track levels of function declarations so that a `return`
     statement outside a function can be reported as an error.
     */
    private var funcState = NestingCounter()

    func analyze(_ statement: Statement) throws
    {
        switch statement {
            case let .classDecl(name: _, methods: methods):
                try self.analyzeClass(methods: methods)
            case let .functionDecl(identifier: _, parameters: _, body: body):
                try self.analyzeFunction(body)
            case let .variableDecl(name: _, initializer: initalizer):
                // Declaration with '.this' as name is caught by the Parser
                try initalizer.flatMap(self.analyze)
            case let .expression(expression):
                try self.analyze(expression)
            case let .conditional(condition, then: thenBranch, else: elseBranch):
                try self.analyze(condition)
                try self.analyze(thenBranch)
                try elseBranch.flatMap(self.analyze)
            case let .print(expression):
                try self.analyze(expression)
            case let .return(token, value: _):
                try self.analyzeReturn(at: token)
            case let .loop(condition: condition, body: body):
                try self.analyze(condition)
                try self.analyze(body)
            case let .breakLoop(token):
                try self.analyzeBreak(token)
            case let .block(statements):
                for statement in statements {
                    try self.analyze(statement)
                }
        }
    }

    //MARK:- Statement analysis

    private func analyzeClass(methods: [Statement]) throws
    {
        self.classState++
        defer { self.classState-- }

        for method in methods {
            try self.analyze(method)
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

    //MARK:- Expression analysis

    private func analyze(_ expression: Expression) throws
    {
        switch expression {
            case let .this(keyword, resolution: _):
                try self.analyzeInstanceRef(keyword)
            default:
                return
        }
    }

    private func analyzeInstanceRef(_ keyword: Token) throws
    {
        guard self.classState.isNested && self.funcState.isNested else {
            throw SemanticError.misplacedObjectRef(at: keyword)
        }
    }
}

private extension SemanticError
{
    static func misplacedReturn(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Cannot return outside a function or method")
    }

    static func misplacedBreak(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Cannot break outside a loop")
    }

    static func misplacedObjectRef(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Cannot use '\(token.lexeme)' outside a method")
    }
}
