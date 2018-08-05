import Foundation

extension Callable
{
    static let clock = Callable(name: "clock", arity: 0) {
        (_, _) in .double(Date().timeIntervalSinceReferenceDate)
    }
}
