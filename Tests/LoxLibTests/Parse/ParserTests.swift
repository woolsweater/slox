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

        XCTAssertEqual(expression, parser.parse())
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
            Token.leftParen, ] +
            firstGroup + [
            Token.rightParen,
            Token(punctuation: .comma),
            Token.leftParen, ] +
            secondGroup + [
            Token.rightParen,
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

        XCTAssertEqual(expression, parser.parse())
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

        XCTAssertEqual(expression, parser.parse())
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

            XCTAssertEqual(expression, parser.parse())
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
                Token.leftParen, ] +
                firstGroup + [
                Token.rightParen,
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

            XCTAssertEqual(expression, parser.parse())
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

            XCTAssertEqual(expression, parser.parse())
        }
    }

    //MARK:- Primary

    /**
     Verify the expression produced when parsing a single keyword token,
     such as `true` or `nil`.
     */
    func testPrimaryKeyword()
    {
        let keywordsAndExpressions: [(Token, Expression)] = [
            (Token(keyword: .false), Expression.false),
            (Token(keyword: .true), Expression.true),
            (Token(keyword: .nil), Expression.nil),
        ]

        for (keyword, expression) in keywordsAndExpressions {
            let parser = Parser(tokens: [keyword, Token.eof(1)])
            XCTAssertEqual(expression, parser.parse())
        }
    }

    /**
     Verify the expression produced when parsing a string token.
     */
    func testPrimaryStrings()
    {
        let string = "Hello, world!"
        let token = Token(string: string)
        let expression = Expression(string: string)

        let parser = Parser(tokens: [token, Token.eof(1)])

        XCTAssertEqual(expression, parser.parse())
    }

    /**
     Verify the expression produced when parsing a number token.
     */
    func testPrimaryNumbers()
    {
        let number: Double = 1024
        let token = Token(number: number)
        let expression = Expression(number: number)

        let parser = Parser(tokens: [token, Token.eof(1)])

        XCTAssertEqual(expression, parser.parse())
    }

    /**
     Verify the expression produced when parsing a grouping composed of
     another primary.
     */
    func testPrimaryGrouping()
    {
        let number: Double = 10
        let tokens = [
            Token.leftParen,
            Token(number: number),
            Token.rightParen,
            Token.eof(1)
        ]
        let expression = Expression.grouping(Expression(number: number))

        let parser = Parser(tokens: tokens)

        XCTAssertEqual(expression, parser.parse())
    }

    /**
     Verify that a grouping that is missing its closing parenthesis
     causes parsing to fail.
     */
    func testPrimaryUntermiatedGrouping()
    {
        let tokens = [
            Token.leftParen,
            Token(number: 10),
            Token.eof(1)
        ]

        let parser = Parser(tokens: tokens)

        XCTAssertNil(parser.parse())
        XCTAssertTrue(Lox.hasError)

    }

    /**
     Verify the expression produced when parsing a grouping with an extra
     trailing parenthesis.
     - remark: The grouping exprssion should be parsed and returned, but
     an error should be reported.
     */
    func testPrimaryGroupingError()
    {
        let number: Double = 10
        let tokens = [
            Token.leftParen,
            Token(number: number),
            Token.rightParen,
            Token.rightParen,
            Token.eof(1)
        ]
        let expression = Expression.grouping(Expression(number: number))

        let parser = Parser(tokens: tokens)

        XCTAssertEqual(expression, parser.parse())
        XCTAssertTrue(Lox.hasError)
    }
}
