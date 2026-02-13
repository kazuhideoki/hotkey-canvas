import SwiftUI

// TEMP: Bootstrap-only SwiftUI view to verify app launch and rendering. Remove after canvas screen is introduced.
public struct GreetingView: View {
    @StateObject private var viewModel: GreetingViewModel

    public init(viewModel: GreetingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Text(viewModel.greetingText)
            .padding(24)
            .frame(minWidth: 300, minHeight: 180)
            .task {
                await viewModel.onAppear()
            }
    }
}
