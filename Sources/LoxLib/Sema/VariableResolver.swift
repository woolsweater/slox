import Foundation

/**
 Walks the AST looking for references to variables, recording index information
 in the tree for the interpreter to use when looking up the variable.
 */
class VariableResolver : SemanticAnalyzer
{
    /**
     Keep track of the state of a variable's declaration, keyed by the name
     of the variable. Each dictionary is a static scope, corresponding to
     an `Environment` during interpretation.
     */
    private var scopes: [[String : VariableResolution]] = [[:]]

    func analyze(_ statement: Statement) throws
    {
        switch statement {
            case let .functionDecl(identifier: identifier, parameters: parameters, body: body):
                try self.analyzeFunctionDecl(identifier, parameters: parameters, body: body)
            case let .variableDecl(name: name, initializer: initializer):
                try self.analyzeVariableDecl(name, initializer: initializer)
            case let .expression(expression):
                try self.analyze(expression)
            case let .conditional(condition, then: thenBranch, else: elseBranch):
                try self.analyzeConditional(condition, then: thenBranch, else: elseBranch)
            case let .print(expression):
                try self.analyze(expression)
            case let .return(_, value: value):
                try value.flatMap(self.analyze)
            case let .loop(condition: condition, body: body):
                try self.analyzeLoop(condition, body: body)
            case .breakLoop:
                break
            case let .block(statements):
                try self.analyzeBlock(statements)
        }
    }

    private func analyzeFunctionDecl(_ identifier: Token, parameters: [Token], body: [Statement]) throws
    {
        self.declare(variable: identifier)
        self.define(variable: identifier)

        try self.analyzeFunction(parameters: parameters, body: body)
    }

    private func analyzeVariableDecl(_ name: Token, initializer: Expression?) throws
    {
        self.declare(variable: name)
        if let initializer = initializer {
            try self.analyze(initializer)
        }
        self.define(variable: name)
    }

    private func analyzeConditional(_ condition: Expression, then: Statement, else: Statement?) throws
    {
        try self.analyze(condition)
        try self.analyze(then)
        if let elseBranch = `else` {
            try self.analyze(elseBranch)
        }
    }

    private func analyzeLoop(_ condition: Expression, body: Statement) throws
    {
        try self.analyze(condition)
        try self.analyze(body)
    }

    private func analyzeBlock(_ statements: [Statement]) throws
    {
        self.beginScope()
        defer { self.endScope() }

        for statement in statements {
            try self.analyze(statement)
        }
    }

    private func analyzeFunction(parameters: [Token], body: [Statement]) throws
    {
        self.beginScope()
        defer { self.endScope() }

        for param in parameters {
            self.declare(variable: param)
            self.define(variable: param)
        }

        for statement in body {
            try self.analyze(statement)
        }
    }

    //MARK:- Expression resolution

    private func analyze(_ expression: Expression) throws
    {
        switch expression {
            case .literal(_):
                break
            case let .grouping(inner):
                try self.analyze(inner)
            case let .variable(name, resolution: resolution):
                try self.resolveVariable(name, resolution: resolution)
            case let .anonFunction(id: _, parameters: parameters, body: body):
                try self.analyzeFunction(parameters: parameters, body: body)
            case let .call(callee, paren: _, arguments: arguments):
                try self.analyzeCall(callee, arguments: arguments)
            case let .unary(op: _, operand):
                try self.analyze(operand)
            case let .binary(left: left, op: _, right: right),
                 let .logical(left: left, op: _, right: right):
                try self.analyze(left)
                try self.analyze(right)
            case let .assignment(name: name, value: value, resolution: resolution):
                try self.resolveAssignment(name, value: value, resolution: resolution)
        }
    }

    private func resolveVariable(_ name: Token, resolution: ScopeResolution) throws
    {
        guard self.scopes.last?[name.lexeme]?.isDefined != false else {
            throw SemanticError.uninitialized(at: name)
        }

        for (steps, scope) in self.scopes.reversed().enumerated() {
            if let variable = scope[name.lexeme] {
                resolution.environmentDistance = steps
                resolution.index = variable.slot
                return
            }
        }

        // Not found. Assume it is global.
    }

    private func analyzeCall(_ callee: Expression, arguments: [Expression]) throws
    {
        try self.analyze(callee)

        for argument in arguments {
            try self.analyze(argument)
        }
    }

    private func resolveAssignment(_ name: Token, value: Expression, resolution: ScopeResolution) throws
    {
        try self.analyze(value)
        try self.resolveVariable(name, resolution: resolution)
    }

    //MARK:- Scope

    private func declare(variable: Token)
    {
        guard var currentScope = self.scopes.popLast() else { return }

        currentScope[variable.lexeme] = VariableResolution(slot: currentScope.count)
        self.scopes.append(currentScope)
    }

    private func define(variable: Token)
    {
        guard var currentScope = self.scopes.popLast() else { return }

        currentScope[variable.lexeme]!.isDefined = true
        self.scopes.append(currentScope)
    }

    private func beginScope()
    {
        self.scopes.append([:])
    }

    private func endScope()
    {
        _ = self.scopes.popLast()
    }
}

/** The analyzed state of a declared variable. */
private struct VariableResolution
{
    /**
     Whether the variable's declaration and initialization are complete.
     - remark: Note that this does not mean there was a value explicitly provided, just
     that the analyzer has moved past the variable's declaration without error.
     */
    var isDefined: Bool = false

    /**
     The ordinal position of the variable in the scope where it's declared.
     - remark: This is stored in the appropriate AST node and used by the
     `Interpreter` to look up the variable correctly.
     */
    let slot: Int

    init(slot: Int)
    {
        self.slot = slot
    }
}

private extension SemanticError
{
    static func uninitialized(at token: Token) -> SemanticError
    {
        return SemanticError(token: token, message: "Variable used in its own initializer")
    }
}