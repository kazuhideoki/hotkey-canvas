import SwiftUI

// TEMP: Bootstrap-only SwiftUI view to verify app launch and rendering. Remove after canvas screen is introduced.
public struct GreetingView: View {
    @StateObject private var viewModel: GreetingViewModel
    @FocusState private var isInputFocused: Bool

    public init(viewModel: GreetingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

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
