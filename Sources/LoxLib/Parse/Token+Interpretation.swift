import Foundation

/**
 A function or operator that combines two `Double` values
 to produce a new value.
 */
typealias ArithmeticOperation = (Double, Double) -> Double

/**
 A function or operator that compares two `Double` values
 to produce a boolean value.
 */
typealias ComparisonOperation = (Double, Double) -> Bool

extension Token
{
    /**
     The `ArithmeticOperation` represented by this token kind, or `nil`
     if this token does not represent an arithmetic operator.
     */
    var arithmeticOperation: ArithmeticOperation?
    {
        switch self.kind {
            case .minus: return (-)
            case .slash: return (/)
            case .star: return (*)
            case .plus: return (+)
            default: return nil
        }
    }

    /**
     The `ComparisonOperation` represented by this token kind,
     or `nil` if this token does not represent a comparison operator.
     */
    var comparisonOperation: ComparisonOperation?
    {
        switch self.kind {
            case .greater: return (>)
            case .greaterEqual: return (>=)
            case .less: return (<)
            case .lessEqual: return (<=)
            default: return nil
        }
    }
}
