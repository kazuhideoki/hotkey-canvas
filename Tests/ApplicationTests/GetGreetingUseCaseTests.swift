import Application
import Testing

// TEMP: Bootstrap test for hello-world flow. Remove when greeting scaffold is deleted.
@Test("GetGreetingUseCase returns hello world")
func test_getGreeting_returnsHelloWorld() async {
    let sut = GetGreetingUseCase()
    let greeting = await sut.getGreeting()
    #expect(greeting.text == "hello world")
}
