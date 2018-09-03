import Foundation

/**
 Coordinates all `SemanticAnalyzer`s that need to be invoked for the current
 program execution.
 - remark: A `VariableResolver` pass is always included as the last analyzer, as it is required
 by `Interpreter`.
 */
class Analyzer
{
    private let analyzers: [SemanticAnalyzer]

    /**
     Create an `Analyzer` containing the given `SemanticAnalyzer`s.
     - remark: The analyzers will be run on each statement in the program in the order provided.
     Each statement will be fully analyzed before moving on to the next one. This gives
     error-producing analyzers the ability to short-circuit analysis if a major problem is found.
     */
    init(analyzers: SemanticAnalyzer...)
    {
        self.analyzers = analyzers + [VariableResolver()]
    }

    /** Hand off the given AST to each registered analyzer. */
    func analyze(_ program: [Statement])
    {
        for statement in program {
            for analyzer in self.analyzers {
                do { try analyzer.analyze(statement) }
                catch let error as SemanticError {
                    self.reportSemanticError(error)
                    return
                }
                catch {
                    fatalError("Unknown analysis failure: \(error)")
                }
            }
        }
    }

    //MARK:- Error handling

    private func reportSemanticError(_ error: SemanticError)
    {
        let token = error.token
        let locationDescription = token.kind == .EOF ? "end" : "'\(token.lexeme)'"
        Lox.report(at: token.line,
             location: "at \(locationDescription)",
              message: error.message)
    }
}
