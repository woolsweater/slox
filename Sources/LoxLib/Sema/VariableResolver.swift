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
            case let .classDecl(name: name, superclass: superclass, methods: methods):
                try self.analyzeClassDecl(name: name, superclass: superclass, methods: methods)
            case let .functionDecl(identifier: identifier, parameters: parameters, body: body):
                try self.analyzeFunctionDecl(identifier, parameters: parameters, body: body)
            case .getterDecl(_, _):
                // The Parser should not have produced a top-level .getterDecl
                fatalError("Getter decl should only be present in a class body")
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

    private func analyzeClassDecl(name: Token, superclass: Expression?, methods: [Statement]) throws
    {
        try self.declare(name: name)

        var superToken: Token? = nil
        if let superclass = superclass {
            guard case let .variable(superName, resolution: resolution) = superclass else {
                fatalError("Class decl should have '.variable' in superclass position")
            }
            try self.resolveVariable(superName, resolution: resolution)
            superToken = superName
        }

        self.define(name: name)

        try self.withSuperDefined(at: superToken) {

            var uniqueMethodNames: Set<String> = []
            for decl in methods {
                guard let (identifier, parameters, body, _) = decl.unpackClassMember() else {
                    fatalError("Non-class-member statement \(decl) in class decl body")
                }

                guard case (true, _) = uniqueMethodNames.insert(identifier.lexeme) else {
                    throw SemanticError.redefinition(at: identifier)
                }

                try self.analyzeFunction(parameters: parameters, body: body)
            }
        }
    }

    private func withSuperDefined(at token: Token?, _ body: () throws -> Void) throws
    {
        guard let token = token else {
            try body()
            return
        }

        self.beginScope()

        let superToken = Token.superclass(at: token.line)
        // New scope, cannot collide with existing name
        try! self.declare(name: superToken)
        self.define(name: superToken)

        try body()

        try self.endScope()
    }

    private func analyzeFunctionDecl(_ identifier: Token, parameters: [Token], body: [Statement]) throws
    {
        try self.declare(name: identifier)
        self.define(name: identifier)

        try self.analyzeFunction(parameters: parameters, body: body)
    }

    private func analyzeVariableDecl(_ name: Token, initializer: Expression?) throws
    {
        try self.declare(name: name)
        if let initializer = initializer {
            try self.analyze(initializer)
        }
        self.define(name: name)
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

        for statement in statements {
            try self.analyze(statement)
        }

        try self.endScope()
    }

    private func analyzeFunction(parameters: [Token], body: [Statement]) throws
    {
        self.beginScope()

        for param in parameters {
            try self.declare(name: param, isParameter: true)
            self.define(name: param)
        }

        for statement in body {
            try self.analyze(statement)
        }

        try self.endScope()
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
            case let .get(object: object, member: _):
                try self.analyze(object)
            case let .set(object: object, member: _, value: value):
                try self.analyze(object)
                try self.analyze(value)
            case let .this(keyword, resolution: resolution):
                try self.resolveVariable(keyword, resolution: resolution)
            case let .super(keyword, method: _, classResolution: classRes, instanceResolution: instanceRes):
                try self.resolveSuper(keyword, classResolution: classRes, instanceResolution: instanceRes)
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
                variable.isUnused = false
                return
            }
        }

        // Not found. Assume it is global.
    }

    private func resolveSuper(_ keyword: Token,
                        classResolution: ScopeResolution,
                     instanceResolution: ScopeResolution) throws
    {
        try self.resolveVariable(keyword, resolution: classResolution)
        try self.resolveVariable(Token.instanceRef(at: keyword.line),
                                 resolution: instanceResolution)
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

    private func declare(name: Token, isParameter: Bool = false) throws
    {
        guard var currentScope = self.scopes.popLast() else { return }
        guard !(currentScope.keys.contains(name.lexeme)) else {
            throw SemanticError.redefinition(at: name)
        }

        currentScope[name.lexeme] =
            VariableResolution(slot: currentScope.count, token: name, isParameter: isParameter)
        self.scopes.append(currentScope)
    }

    private func define(name: Token)
    {
        guard let currentScope = self.scopes.popLast() else { return }

        currentScope[name.lexeme]!.isDefined = true
        self.scopes.append(currentScope)
    }

    private func beginScope()
    {
        self.scopes.append([:])
    }

    /**
     Remove the current scope, checking for variables that were declared here but that
     have never been referenced. These are reported as warnings.
     */
    private func endScope() throws
    {
        guard let scope = self.scopes.popLast() else { return }
        let warnings = scope.values
                            .filter({ $0.isUnused && !($0.token.isInstanceRef) })
                            .map(SemanticWarning.unusedVariable)
        guard warnings.isEmpty else {
            throw SemanticBlockWarning(warnings: warnings)
        }
    }
}

/** The analyzed state of a declared variable. */
private class VariableResolution
{
    /**
     Whether the variable's declaration and initialization are complete.
     - remark: Note that this does not mean there was a value explicitly provided, just
     that the analyzer has moved past the variable's declaration without error.
     */
    var isDefined = false

    /**
     Whether the variable has been accessed in referred to at some point. If not, this
     is reported as a warning when the analyzer finishes with the scope containing the
     variable.
     */
    var isUnused = true

    /**
     The ordinal position of the variable in the scope where it's declared.
     - remark: This is stored in the appropriate AST node and used by the
     `Interpreter` to look up the variable correctly.
     */
    let slot: Int

    /**
     The token where the variable was declared. This is used for error reporting.
     */
    let token: Token

    /**
     Whether this is the parameter of a function/method declaration. This is
     used for error reporting.
     */
    let isParameter: Bool

    init(slot: Int, token: Token, isParameter: Bool)
    {
        self.slot = slot
        self.token = token
        self.isParameter = isParameter
    }
}

private extension SemanticError
{
    static func uninitialized(at token: Token) -> SemanticError
    {
        return SemanticError(token: token,
                           message: "Variable cannot be used in its own initializer")
    }

    static func redefinition(at token: Token) -> SemanticError
    {
        return SemanticError(token: token,
                           message: "Redefinition of name '\(token.lexeme)'")
    }
}

private extension SemanticWarning
{
    static func unusedVariable(_ variable: VariableResolution) -> SemanticWarning
    {
        let message = variable.isParameter ?
                        "Parameter unused in body" :
                        "Variable declared but never used"
        return SemanticWarning(token: variable.token, message: message)
    }
}
