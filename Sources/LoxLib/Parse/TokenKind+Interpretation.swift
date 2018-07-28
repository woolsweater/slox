extension Token.Kind
{
    var arithmeticOperation: ((Double, Double) -> Double)?
    {
        switch self {
            case .minus: return (-)
            case .slash: return (/)
            case .star: return (*)
            case .plus: return (+)
            default: return nil
        }
    }

    var comparisonOperation: ((Double, Double) -> Bool)?
    {
        switch self {
            case .greater: return (>)
            case .greaterEqual: return (>=)
            case .less: return (<)
            case .lessEqual: return (<=)
            default: return nil
        }
    }
}
