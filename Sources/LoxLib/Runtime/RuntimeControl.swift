// "Errors" that are used to move control around within the interpreter.

/** Move control immediately to the end of the nearest enclosing loop. */
struct BreakLoop : Error {}

/**
 Move control immediately to the end of the currently-executing function,
 producing the contained `value`.
 */
struct Return : Error
{
    let value: LoxValue
}
