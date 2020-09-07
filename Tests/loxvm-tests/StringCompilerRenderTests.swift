import XCTest
@testable import loxvm_testable

/**
 High-level tests for `StringCompiler`. These check that the rendering
 of various input strings is equivalent as far as the implementation
 language (Swift) is concerned.
 */
class StringCompilerRenderTests : XCTestCase
{
    private var compiler: StringCompiler!

    override func setUp()
    {
        super.setUp()
        self.compiler = StringCompiler(allocate: { UnsafeMutableBufferPointer<UInt8>.allocate(capacity: $0) },
                                        destroy: { $0.deallocate() })
    }

    /**
     Test that the empty string is handled correctly; the output
     should also be an empty string.
     */
    func testEmptyString() throws
    {
        try self.evaluateRendering(input: "", expected: "")
    }

    /**
     Test the compiler's handling of strings that contain no escape
     sequences. The rendered string should be the same as the input.
     */
    func testPlainStrings() throws
    {
        let hello = "Hello!"
        try self.evaluateRendering(input: hello, expected: hello)

        let lorem = "Lorem ipsum dolor sit amet"
        try self.evaluateRendering(input: lorem, expected: lorem)

        let multiline = """
        'Twas brillig, and the slithy toves
        Did gyre and gimble in the wabe
        All mimsy were the borogoves
        """
        try self.evaluateRendering(input: multiline, expected: multiline)
    }

    /**
     Test the compiler's handling of the supported single-character escape
     sequences.
     */
    func testSimpleEscapes() throws
    {
        let newlines = #"'Twas brillig, and the slithy toves\nDid gyre and gimble in the wabe\nAll mimsy were the borogoves"#
        let newlinesRendered = """
        'Twas brillig, and the slithy toves
        Did gyre and gimble in the wabe
        All mimsy were the borogoves
        """
        try self.evaluateRendering(input: newlines,
                                expected: newlinesRendered)

        try self.evaluateRendering(input: #"Hello\t\tworld\t!"#,
                                expected: "Hello\t\tworld\t!")

        try self.evaluateRendering(input: #"One backslash: \\ Two backslashes: \\\\"#,
                                expected: #"One backslash: \ Two backslashes: \\"#)

        try self.evaluateRendering(input: #"She said \"I know what it's like to be dead\""#,
                                expected: #"She said "I know what it's like to be dead""#)

        try self.evaluateRendering(input: #"One line\rSame line\r\nNext line"#,
                                expected: "One line\rSame line\r\nNext line")
    }

    /**
     Test the compiler's handling of `\uXXXX;` escapes. The rendered string should
     correctly encode the codepoints specified by the escape sequences so that it
     is equivalent to a string rendered by the implementation language.
     */
    func testUnicodeEscapes() throws
    {
        try self.evaluateRendering(input: #"This \"cafe\u00301;\" doesn't have coffee! \u1f62e;"#,
                                expected: #"This "café" doesn't have coffee! 😮"#)

        try self.evaluateRendering(input: #"I visited a lovely pa\u0302;tisserie in \u1f1eb;\u001F1F7; with my whole \u001F469;\u200D;\u1F469;\u200D;\u001F467;\u200D;\u01F466;"#,
                                expected: "I visited a lovely pâtisserie in 🇫🇷 with my whole 👩‍👩‍👧‍👦")
    }

    /**
     Test that input strings that already contain non-ASCII text, including
     emoji, are passed through without being corrupted.
     */
    func testUnicodeInput() throws
    {
        let lunch = "This \"café\" doesn't have coffee! 😮"
        try self.evaluateRendering(input: lunch, expected: lunch)

        let vacation = "I visited a lovely pa\u{0302}tisserie in 🇫🇷 with my whole 👩‍👩‍👧‍👦"
        try self.evaluateRendering(input: vacation, expected: vacation)
    }

    private func evaluateRendering(input: String, expected: String) throws
    {
        try self.compiler.withRenderedEscapes(in: input[...]) {
            let rendered = String(cString: $0.baseAddress!)
            XCTAssertEqual(expected, rendered)
        }
    }
}
