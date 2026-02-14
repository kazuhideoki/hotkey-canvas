// Background: Temporary greeting model still needs a basic contract test.
// Responsibility: Verify Greeting stores constructor-provided text.
import Domain
import Testing

@Test("Greeting stores text")
func test_greeting_text_isStored() {
    let greeting = Greeting(text: "hello world")
    #expect(greeting.text == "hello world")
}
