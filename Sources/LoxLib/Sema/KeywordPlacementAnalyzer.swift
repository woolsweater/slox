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
     Track class nesting so that a `this` reference outside a class can be
     reported as an error.
     */
    private var classState = NestingCounter()

    /**
     Track kinds of function declarations so illegal `return` statements can
     be reported as errors.
     - remark: We check for simple usage of `return` outside any kind of function.
     we also flag a return statement with a value as an error inside of a class
     initializer.
     */
    private var funcState = StateTracker<FuncKind>()

    func analyze(_ statement: Statement) throws
    {
        switch statement {
            case let .classDecl(name: _, methods: methods):
                try self.analyzeClass(methods: methods)
            case let .functionDecl(identifier: name, parameters: _, body: body):
                try self.analyzeFunction(name: name, body: body)
            case let .getterDecl(identifier: name, body: body):
                try self.analyzeGetter(name: name, body: body)
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
            case let .return(token, value: value):
                try self.analyzeReturn(at: token, value: value)
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

    private func analyzeFunction(name: Token, body: [Statement]) throws
    {
        let state: FuncKind =
            self.classState.isNested
                ? (name.lexeme == LoxClass.initializerName) ? .initializer : .method
                : .function

        self.funcState += state
        defer { self.funcState-- }

        try self.finishAnalyzingFunction(name: name, body: body)
    }

    private func analyzeGetter(name: Token, body: [Statement]) throws
    {
        self.funcState += .getter
        defer { self.funcState-- }

        try self.finishAnalyzingFunction(name: name, body: body)
    }

    private func finishAnalyzingFunction(name: Token, body: [Statement]) throws
    {
        var earlyReturnTokens: [Token] = []
        for statement in body.dropLast() {
            if case let .return(token, value: _) = statement {
                earlyReturnTokens.append(token)
            }
            try self.analyze(statement)
        }

        let lastStatement = body.last
        if self.funcState.current == .getter {
            guard case .return(_)? = lastStatement else {
                throw SemanticError.missingReturn(at: name)
            }
        }

        try lastStatement.flatMap(self.analyze)

        guard earlyReturnTokens.isEmpty else {
            let warnings = earlyReturnTokens.map(SemanticWarning.prematureReturn)
            throw SemanticBlockWarning(warnings: warnings)
        }
    }

    private func analyzeReturn(at token: Token, value: Expression?) throws
    {
        guard self.funcState.isNested else {
            throw SemanticError.misplacedReturn(at: token)
        }

        if self.funcState.current == .initializer {
            guard value == nil else {
                throw SemanticError.initReturningValue(at: token)
            }
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
        guard self.funcState.current ~ [.method, .initializer] else {
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

    static func initReturningValue(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Cannot return a value from 'init'")
    }

    static func missingReturn(at token: Token) -> SemanticError
    {
        return SemanticError(token: token,
                           message: "Getter must have return as its final statement")
    }
}

private extension SemanticWarning
{
    static func prematureReturn(at token: Token) -> SemanticWarning
    {
        return SemanticWarning(token: token,
                             message: "Code after 'return' will never be executed")
    }
}
