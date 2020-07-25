import Foundation

infix operator |> : MultiplicationPrecedence
func |> <T, U> (input: T, operation: (T) -> U) -> U {
    operation(input)
}
