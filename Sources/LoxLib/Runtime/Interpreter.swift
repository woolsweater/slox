import Foundation

class Interpreter
{
    /**
     Top-level evironment which holds builtins and other internal values,
     such as the REPL's "cut".
     */
    private let globals = GlobalEnvironment()

    /**
     Values of variables in the current scope. Changes as blocks are entered
     and exited.
     */
    private var environment = Environment()

    /**
     Whether the interpreter is running in a REPL instead of interpreting a
     file. In the REPL case, the evaluated result of each expression statement
     will be printed and also stored in a special "cut" variable.
     */
    private let isRepl: Bool

    init(replMode: Bool)
    {
        self.isRepl = replMode
        if self.isRepl {
            self.globals.createCut()
        }
        self.globals.defineBuiltin(Callable.clock)
    }

    func interpret(_ program: [Statement]) {
        do {
            for statement in program {
                try self.execute(statement)
            }
        }
        catch let error as RuntimeError {
            self.reportRuntimeError(error)
        }
        catch {
            fatalError("Unknown interpretation failure: \(error)")
        }
    }

    private func execute(_ statement: Statement) throws
    {
        switch statement {
            case let .classDecl(name: name, methods: methods):
                self.evaluateClassDecl(name: name, methods: methods)
            case let .functionDecl(identifier: ident, parameters: parameters, body: body):
                self.evaluateFunctionDecl(identifier: ident, parameters: parameters, body: body)
            case .getterDecl(_):
                // The Parser should not have produced a top-level .getterDecl
                fatalError("Getter decl should only be present in a class body")
            case let .variableDecl(name: name, initializer: expression):
                try self.evaluateVariableDecl(name: name, initializer: expression)
            case let .expression(expression):
                let value = try self.evaluate(expression)
                if self.isRepl {
                    print(self.stringify(value))
                    try self.globals.updateCut(value: value)
                }
            case let .conditional(condition, then: thenBranch, else: elseBranch):
                try self.executeConditional(condition,
                                            thenBranch: thenBranch,
                                            elseBranch: elseBranch)
            case let .print(expression):
                let value = try self.evaluate(expression)
                print(self.stringify(value))
            case let .return(token, value: value):
                try self.executeReturn(token, value: value)
            case let .loop(condition: condition, body: body):
                try self.executeLoop(condition: condition, body: body)
            case .breakLoop:
                throw BreakLoop()
            case let .block(statements):
                try self.executeBlock(statements, environment: Environment(nestedIn: self.environment))
        }
    }

    private func evaluate(_ expression: Expression) throws -> LoxValue
    {
        switch expression {
            case let .literal(literal):
                return literal.loxValue
            case let .grouping(groupedExpression):
                return try self.evaluate(groupedExpression)
            case let .variable(name, resolution: resolution):
                return try self.lookUp(variable: name, resolution: resolution)
            case let .anonFunction(id: id, parameters: parameters, body: body):
                let function = self.callableFunction(name: "__unnamedFunc\(id)",
                                                     kind: .function,
                                               parameters: parameters,
                                                     body: body)
                return .callable(function)
            case let .call(callee, paren: paren, arguments: arguments):
                return try self.evaluateCall(to: callee, passing: arguments, paren: paren)
            case let .get(object: object, member: member):
                return try self.evaluateGet(object: object, member: member)
            case let .set(object: object, member: member, value: value):
                return try self.evaluateSet(object: object, member: member, value: value)
            case let .this(keyword, resolution: resolution):
                return try self.lookUp(variable: keyword, resolution: resolution)
            case let .unary(op: opToken, operand):
                return try self.evaluateUnary(op: opToken, operand)
            case let .binary(left: left, op: opToken, right: right):
                return try self.evaluateBinary(leftExpr: left,
                                                      op: opToken,
                                               rightExpr: right)
            case let .assignment(name: name, value: value, resolution: resolution):
                return try self.evaluateAssignment(name: name,
                                                  value: value,
                                             resolution: resolution)
            case let .logical(left: left, op: op, right: right):
                return try self.evaluateLogical(leftExpr: left, op: op, rightExpr: right)
        }
    }

    //MARK:- Class declaration

    private func evaluateClassDecl(name: Token, methods: [Statement])
    {
       let methodMap =
           // Uniqueness of method names checked by VariableResolver
           Dictionary(uniqueKeysWithValues: methods.map(self.statementToMethod))

        let klass = LoxClass(name: name.lexeme, methods: methodMap)

        self.environment.define(value: .class(klass))
    }

    private func statementToMethod(_ statement: Statement) -> (String, Callable)
    {
        guard let (identifier, parameters, body, kind) = statement.unpackClassMember() else {
            fatalError("Non-class-member statement \(statement) in class decl body")
        }

        let methodName = identifier.lexeme
        let callable = self.callableFunction(name: methodName,
                                             kind: kind,
                                       parameters: parameters,
                                             body: body)
        return (methodName, callable)
    }

    //MARK:- Function definition

    private func evaluateFunctionDecl(identifier: Token, parameters: [Token], body: [Statement])
    {
        let function = self.callableFunction(name: identifier.lexeme,
                                             kind: .function,
                                       parameters: parameters,
                                             body: body)

        self.environment.define(value: .callable(function))
    }

    /** Create a `Callable` for a function or method. */
    private func callableFunction(name: String,
                                  kind: FuncKind,
                            parameters: [Token],
                                  body: [Statement])
        -> Callable
    {
        let function = Callable.fromDecl(name: name,
                                         kind: kind,
                                   parameters: parameters,
                                         body: body,
                                  environment: self.environment)
        return function
    }

    //MARK:- Variables

    private func evaluateVariableDecl(name: Token, initializer: Expression?) throws
    {
        let value = try initializer.flatMap(self.evaluate)
        self.environment.define(value: value)
    }

    private func evaluateAssignment(name: Token,
                                   value: Expression,
                              resolution: ScopeResolution)
        throws -> LoxValue
    {
        let evaluated = try self.evaluate(value)
        if let distance = resolution.environmentDistance, let index = resolution.index {
            try self.environment.assign(variable: name,
                                           value: evaluated,
                                        distance: distance,
                                           index: index)
        }
        else {
            try self.globals.assign(name: name, value: evaluated)
        }

        return evaluated
    }

    //MARK:- Conditional

    private func executeConditional(_ condition: Expression, thenBranch: Statement, elseBranch: Statement?) throws
    {
        let conditionValue = try self.evaluate(condition)
        if self.truthValue(of: conditionValue) {
            try self.execute(thenBranch)
        }
        else {
            try elseBranch.flatMap(self.execute)
        }
    }

    //MARK:- Return statement

    private func executeReturn(_ keyword: Token, value: Expression?) throws
    {
        let returnValue = try value.flatMap(self.evaluate)
        throw Return(value: returnValue ?? .nil)
    }

    //MARK:- Loop

    private func executeLoop(condition: Expression, body: Statement) throws
    {
        do {
            while try self.truthValue(of: self.evaluate(condition)) {
                try self.execute(body)
            }
        }
        catch is BreakLoop {
            return
        }
        catch {
            throw error
        }
    }

    //MARK:- Blocks

    /**
     Execute each statement in the list in order.
     - remark: Needs to be visible to `Callable.fromDecl()` for function
     definitions, hence it is not private.
     */
    func executeBlock(_ statements: [Statement], environment: Environment) throws
    {
        let previousEnvironment = self.environment
        self.environment = environment
        defer { self.environment = previousEnvironment }

        for statement in statements {
            try self.execute(statement)
        }
    }

    //MARK:- Function invocation

    private func evaluateCall(to calleeExpr: Expression,
                           passing argExprs: [Expression],
                                      paren: Token)
        throws -> LoxValue
    {
        let callee = try self.evaluate(calleeExpr)

        let arguments = try argExprs.map({ try self.evaluate($0) })

        if case let .callable(callable) = callee {
            return try callable.invoke(using: self, at: paren, arguments: arguments)
        }
        else if case let .class(klass) = callee {
            return try .instance(klass.allocInit(using: self, at: paren, arguments: arguments))
        }
        else {
            throw RuntimeError.notCallable(at: paren)
        }
    }

    //MARK:- Member access

    private func evaluateGet(object: Expression, member: Token) throws -> LoxValue
    {
        guard case let .instance(instance) = try self.evaluate(object) else {
            throw RuntimeError.notAnObject(at: member)
        }

        let value = try instance.get(member)

        if case let .callable(getter) = value, getter.isImplicitlyInvoked {
            return try getter.invoke(using: self, at: member, arguments: [])
        }
        else {
            return value
        }
    }

    private func evaluateSet(object: Expression, member: Token, value: Expression) throws -> LoxValue
    {
        guard case let .instance(instance) = try self.evaluate(object) else {
            throw RuntimeError.notAnObject(at: member)
        }

        let value = try self.evaluate(value)

        instance.set(member, to: value)
        return value
    }

    //MARK:- Unary

    private func evaluateUnary(op: Token, _ expression: Expression) throws -> LoxValue
    {
        let operandValue = try self.evaluate(expression)

        switch op.kind {
            case .minus:
                guard case let .double(doubleValue) = operandValue else {
                    throw RuntimeError.numeric(at: op)
                }
                return .double(-doubleValue)
            case .bang:
                return .bool(!self.truthValue(of: operandValue))
            default:
                fatalError("Found invalid unary operator \(op.kind)")
        }
    }

    //MARK:- Binary

    private func evaluateBinary(leftExpr: Expression, op: Token, rightExpr: Expression) throws -> LoxValue
    {
        let leftValue = try self.evaluate(leftExpr)
        let rightValue = try self.evaluate(rightExpr)

        switch op.kind {
            case .minus: fallthrough
            case .slash: fallthrough
            case .star:
                guard case let .double(lhs) = leftValue, case let .double(rhs) = rightValue else {
                    throw RuntimeError.numeric(at: op)
                }
                let arithmeticOperation = op.arithmeticOperation!
                return .double(arithmeticOperation(lhs, rhs))
            case .plus:
                if case let .double(lhs) = leftValue, case let .double(rhs) = rightValue {
                    let arithmeticOperation = op.arithmeticOperation!
                    return .double(arithmeticOperation(lhs, rhs))
                }
                else if case let .string(lhs) = leftValue, case let .string(rhs) = rightValue {
                    return .string(lhs + rhs)
                }
                else {
                    throw RuntimeError(token: op,
                                     message: "Operands must be string or number with matching types")
                }
            case .greater: fallthrough
            case .greaterEqual: fallthrough
            case .less: fallthrough
            case .lessEqual:
                guard case let .double(lhs) = leftValue, case let .double(rhs) = rightValue else {
                    throw RuntimeError.numeric(at: op)
                }
                let comparisonOperation = op.comparisonOperation!
                return .bool(comparisonOperation(lhs, rhs))
            case .equalEqual:
                return .bool(leftValue == rightValue)
            case .bangEqual:
                return .bool(leftValue != rightValue)
            case .comma:
                return rightValue
            default:
                fatalError("Found invalid binary operator '\(op.kind)'")
        }
    }

    //MARK:- Logical binary

    private func evaluateLogical(leftExpr: Expression, op: Token, rightExpr: Expression) throws -> LoxValue
    {
        let leftValue = try self.evaluate(leftExpr)
        let isLeftTrue = self.truthValue(of: leftValue)

        switch op.kind {
            case .or:
                if isLeftTrue { return leftValue }
            case .and:
                if !(isLeftTrue) { return leftValue }
            default:
                fatalError("Found non-logical operator '\(op.kind)' in logical expression")
        }

        return try self.evaluate(rightExpr)
    }

    //MARK:- Helper

    private func lookUp(variable: Token, resolution: ScopeResolution) throws -> LoxValue
    {
        if let distance = resolution.environmentDistance, let index = resolution.index {
            return try self.environment.read(variable: variable, at: distance, index: index)
        }
        else if let value = try self.globals.read(name: variable) {
            return value
        }
        else {
            throw RuntimeError.unresolvedVariable(variable)
        }
    }

    private func truthValue(of value: LoxValue) -> Bool
    {
        switch value {
            case let .bool(boolValue):
                return boolValue
            case .nil:
                return false
            default:
                return true
        }
    }

    private func stringify(_ value: LoxValue) -> String
    {
        switch value {
            case let .double(double):
                return self.formatNumber(double)
            case let .string(string):
                return string
            case let .bool(bool):
                return String(describing: bool)
            case let .callable(function):
                return String(describing: function)
            case let .class(klass):
                return "<class \(klass.name)>"
            case let .instance(instance):
                return "<\(instance)>"
            case .nil:
                return "nil"
        }
    }

    private func formatNumber(_ number: Double) -> String {
        if number.isIntegral {
            return String(Int(number))
        } else {
            return String(number)
        }
    }

    //MARK:- Error handling

    private func reportRuntimeError(_ error: RuntimeError)
    {
        let token = error.token
        let locationDescription = token.kind == .EOF ? "end" : "'\(token.lexeme)'"
        Lox.report(at: token.line,
             location: "at \(locationDescription)",
              message: error.message)
    }
}

private extension Double
{
    var isIntegral: Bool { return 0 == self.truncatingRemainder(dividingBy: 1) }
}
