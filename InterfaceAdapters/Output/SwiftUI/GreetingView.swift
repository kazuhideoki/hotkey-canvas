// Background: Bootstrap UI validates app launch and basic user interaction.
// Responsibility: Render greeting text and simple input echo behavior.
import SwiftUI

// TEMP: Bootstrap-only SwiftUI view to verify app launch and rendering. Remove after canvas screen is introduced.
/// Temporary bootstrap view rendered at app startup.
public struct GreetingView: View {
    @StateObject private var viewModel: GreetingViewModel
    @FocusState private var isInputFocused: Bool

    /// Creates a greeting view.
    /// - Parameter viewModel: View model driving displayed state.
    public init(viewModel: GreetingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Declarative view hierarchy for the bootstrap screen.
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.greetingText)

            TextField("Type text and press Enter", text: $viewModel.inputText)
                .focused($isInputFocused)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.submitInput()
                }

            if !viewModel.submittedText.isEmpty {
                Text(viewModel.submittedText)
            }
        }
        .padding(24)
        .frame(minWidth: 300, minHeight: 180, alignment: .topLeading)
        .task {
            await viewModel.onAppear()
        }
        .onAppear {
            DispatchQueue.main.async {
                isInputFocused = true
            }
        }
    }
}
