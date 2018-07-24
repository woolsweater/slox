import XCTest
@testable import LoxLib

/** Tests for the Lox `Parser`. */
class ParserTests : LoxTestCase
{
    /**
     Verify the expression tree produced by parsing two comma-joined
     tokens.
     */
    func testJoined()
    {
        let tokens = [
            Token(string: "Hello"),
            Token(punctuation: .comma),
            Token(string: "world!"),
            Token.eof(1),
        ]

        let expression = Expression.binary(
            left: .literal(tokens[0].literal!),
            op: tokens[1],
            right: .literal(tokens[2].literal!)
        )

        let parser = Parser(tokens: tokens)

        guard let parsed = parser.parse() else {
            XCTFail(); return
        }

        XCTAssertEqual(expression, parsed)
    }

    /**
     Verify the expression trees produced by parsing more complex
     comma-joined expressions.
     */
    func testNestedJoined()
    {
        let firstGroup = [
            Token(number: 10),
            Token(punctuation: .star),
            Token(number: 6),
        ]
        let secondGroup = [
            Token(string: "hello,"),
            Token(punctuation: .comma),
            Token(string: "world!"),
        ]
        let tokens : [Token] = [
            Token(punctuation: .leftParen), ] +
            firstGroup + [
            Token(punctuation: .rightParen),
            Token(punctuation: .comma),
            Token(punctuation: .leftParen), ] +
            secondGroup + [
            Token(punctuation: .rightParen),
            Token.eof(1)
        ]

        let expression = Expression.binary(
            left: .grouping(
                .binary(
                    left: .literal(firstGroup[0].literal!),
                    op: firstGroup[1],
                    right: .literal(firstGroup[2].literal!)
                )
            ),
            op: Token(punctuation: .comma),
            right: .grouping(
                .binary(
                    left: .literal(secondGroup[0].literal!),
                    op: secondGroup[1],
                    right: .literal(secondGroup[2].literal!)
                )
            )
        )

        let parser = Parser(tokens: tokens)

        guard let parsed = parser.parse() else {
            XCTFail(); return
        }

        XCTAssertEqual(expression, parsed)
    }

    /**
     Verify that a comma join with a missing lefthand expression
     reports an error but does not stop parsing altogether.
     */
    func testJoinError()
    {
        let tokens = [
            Token(punctuation: .comma),
            Token(number: 10),
            Token.eof(1)
        ]

        let expression = Expression.literal(tokens[1].literal!)

        let parser = Parser(tokens: tokens)

        guard let parsed = parser.parse() else {
            XCTFail(); return
        }

        XCTAssertEqual(expression, parsed)
        XCTAssertTrue(Lox.hasError)
    }

    //MARK:- Equality

    /**
     Verify the expression tree produced by parsing an equality or
     inequality.
     */
    func testEquality()
    {
        for equalOp in [Token(punctuation: .equalEqual), Token(punctuation: .bangEqual)] {
            let tokens = [
                Token(number: 10),
                equalOp,
                Token(number: 8),
                Token.eof(1)
            ]

            let expression = Expression.binary(
                left: .literal(tokens[0].literal!),
                op: tokens[1],
                right: .literal(tokens[2].literal!)
            )

            let parser = Parser(tokens: tokens)

            guard let parsed = parser.parse() else {
                XCTFail(); return
            }

            XCTAssertEqual(expression, parsed)
        }
    }

    /**
     Verify the expression trees produced by parsing more complex
     equality expressions.
     */
    func testNestedEquality()
    {
        let firstGroup = [
            Token(number: 10),
            Token(punctuation: .star),
            Token(number: 9),
        ]

        let secondGroup = [
            Token(string: "hello,"),
            Token(punctuation: .plus),
            Token(string: "world!"),
        ]

        for equalOp in [Token(punctuation: .equalEqual), Token(punctuation: .bangEqual)] {
            let tokens = [
                Token(punctuation: .leftParen), ] +
                firstGroup + [
                Token(punctuation: .rightParen),
                equalOp, ] +
                secondGroup + [
                Token.eof(1)
            ]

            let expression = Expression.binary(
                left: .grouping(
                    .binary(
                        left: .literal(firstGroup[0].literal!),
                        op: firstGroup[1],
                        right: .literal(firstGroup[2].literal!)
                    )
                ),
                op: equalOp,
                right: .binary(
                    left: .literal(secondGroup[0].literal!),
                    op: secondGroup[1],
                    right: .literal(secondGroup[2].literal!)
                )
            )

            let parser = Parser(tokens: tokens)

            guard let parsed = parser.parse() else {
                XCTFail(); return
            }

            XCTAssertEqual(expression, parsed)
        }
    }

    /**
     Verify that an equality operator with a missing lefthand
     expression reports an error but does not stop parsing altogether.
     */
    func testEqualError()
    {
        for equalOp in [Token(punctuation: .equalEqual), Token(punctuation: .bangEqual)] {

            let tokens = [
                equalOp,
                Token(string: "Hello"),
                Token.eof(1)
            ]

            let expression = Expression.literal(tokens[1].literal!)

            let parser = Parser(tokens: tokens)

            guard let parsed = parser.parse() else {
                XCTFail(); return
            }

            XCTAssertEqual(expression, parsed)
        }
    }
}
