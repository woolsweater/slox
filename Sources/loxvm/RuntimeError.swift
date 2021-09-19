import Foundation
import loxvm_object

/**
 An attempt to use a variable before its declaration was executed.
 */
struct UndefinedVariable : Error
{
    let name: StringRef
    var renderedName: String { String(cString: self.name.chars) }
}
