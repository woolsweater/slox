/** A Lox runtime value, wrapping the appropriate host value. */
enum Value
{
    case bool(Bool)
    case `nil`
    case number(Double)
}
