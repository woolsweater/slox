@testable import LoxLib

extension Expression
{
    static let `false` = Expression.literal(.bool(false))
    static let `true` = Expression.literal(.bool(true))
    static let `nil` = Expression.literal(.nil)

    init(string: String)
    {
        self = .literal(.string(string))
    }

    init(number: Double)
    {
        self = .literal(.double(number))
    }
}
