// Background: ViewModel isolates SwiftUI from application use-case contracts.
// Responsibility: Manage greeting screen state and user input handling.
import Application
import Domain
import Foundation

@MainActor
// TEMP: Bootstrap-only ViewModel for hello-world screen. Remove with initial scaffold UI.
/// Bootstrap view model for greeting screen state.
public final class GreetingViewModel: ObservableObject {
    /// Greeting text loaded from the input port.
    @Published public private(set) var greetingText: String = ""
    /// User input bound to text field.
    @Published public var inputText: String = ""
    /// Last submitted text shown below the input field.
    @Published public private(set) var submittedText: String = ""

    private let inputPort: any GreetingInputPort

    /// Creates a view model with injected application boundary.
    /// - Parameter inputPort: Input port providing greeting data.
    public init(inputPort: any GreetingInputPort) {
        self.inputPort = inputPort
    }

    /// Loads greeting text when the view appears.
    public func onAppear() async {
        let greeting = await inputPort.getGreeting()
        greetingText = greeting.text
    }

    /// Copies current input text into submitted output state.
    public func submitInput() {
        submittedText = inputText
    }
}
