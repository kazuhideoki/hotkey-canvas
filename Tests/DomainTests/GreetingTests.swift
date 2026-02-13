import Domain
import Testing

@Test("Greeting stores text")
func test_greeting_text_isStored() {
    let greeting = Greeting(text: "hello world")
    #expect(greeting.text == "hello world")
}
