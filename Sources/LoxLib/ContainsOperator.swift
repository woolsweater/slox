import Foundation

infix operator ~ : ComparisonPrecedence
/** Test whether the lhs value matches any of the values contained in the rhs group. */
func ~ <T, S : Sequence> (value: T, group: S) -> Bool
    where T : Equatable, S.Element == T
{
    return group.contains(value)
}
