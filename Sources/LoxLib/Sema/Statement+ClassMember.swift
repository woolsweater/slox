import Foundation

extension Statement
{
    /**
     Given a `Statement` that is either a `.functionDecl` or a `.getterDecl`, return the
     identifier token, parameter list (empty for a getter), and body statements, along with
     the appropriate `FuncKind`.
     - note: The returned parameter list *includes* a dummy `.this` token.
     - returns: `nil` if the statement is neither of the two correct cases.
     */
    func unpackClassMember() -> (Token, [Token], [Statement], FuncKind)?
    {
        let identifier: Token
        let parameters: [Token]
        let body: [Statement]
        let isGetter: Bool

        switch self {
            case let .functionDecl(identifier: declIdentifier, parameters: declParameters, body: declBody):
                identifier = declIdentifier
                parameters = declParameters
                body = declBody
                isGetter = false
            case let .getterDecl(identifier: declIdentifier, body: declBody):
                identifier = declIdentifier
                parameters = []
                body = declBody
                isGetter = true
            default:
                return nil
        }

        let parametersWithInstance = [Token.instanceRef(at: identifier.line)] + parameters
        return (identifier, parametersWithInstance, body, isGetter ? .getter : .method)
    }
}
