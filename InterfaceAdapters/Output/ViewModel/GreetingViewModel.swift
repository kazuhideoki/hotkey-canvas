import Application
import Domain
import Foundation

@MainActor
// TEMP: Bootstrap-only ViewModel for hello-world screen. Remove with initial scaffold UI.
public final class GreetingViewModel: ObservableObject {
    @Published public private(set) var greetingText: String = ""

    private let inputPort: any GreetingInputPort

    public init(inputPort: any GreetingInputPort) {
        self.inputPort = inputPort
    }

    public func onAppear() async {
        let greeting = await inputPort.getGreeting()
        greetingText = greeting.text
    }
}
