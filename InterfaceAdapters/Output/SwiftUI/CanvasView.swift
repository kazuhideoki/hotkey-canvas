import SwiftUI

public struct CanvasView: View {
    @StateObject private var viewModel: CanvasViewModel
    private let hotkeyTranslator: CanvasHotkeyTranslator

    public init(
        viewModel: CanvasViewModel,
        hotkeyTranslator: CanvasHotkeyTranslator = CanvasHotkeyTranslator()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.hotkeyTranslator = hotkeyTranslator
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            ForEach(viewModel.nodes, id: \.id) { node in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text(node.text ?? "New Node")
                            .font(.system(size: 14, weight: .medium))
                            .padding(12)
                    }
                    .frame(
                        width: CGFloat(node.bounds.width),
                        height: CGFloat(node.bounds.height),
                        alignment: .topLeading
                    )
                    .offset(x: CGFloat(node.bounds.x), y: CGFloat(node.bounds.y))
            }

            CanvasHotkeyCaptureView { event in
                let commands = hotkeyTranslator.translate(event)
                Task { await viewModel.apply(commands: commands) }
            }
            .frame(width: 1, height: 1)
        }
        .frame(minWidth: 900, minHeight: 600, alignment: .topLeading)
        .task {
            await viewModel.onAppear()
        }
    }
}
