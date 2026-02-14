import Domain
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
        let nodesByID = Dictionary(uniqueKeysWithValues: viewModel.nodes.map { ($0.id, $0) })

        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            ForEach(viewModel.edges, id: \.id) { edge in
                if let fromNode = nodesByID[edge.fromNodeID], let toNode = nodesByID[edge.toNodeID] {
                    Path { path in
                        path.move(to: centerPoint(for: fromNode))
                        path.addLine(to: centerPoint(for: toNode))
                    }
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1.5)
                }
            }

            ForEach(viewModel.nodes, id: \.id) { node in
                let isFocused = viewModel.focusedNodeID == node.id
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isFocused ? 2 : 1
                            )
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
                guard !commands.isEmpty else {
                    return false
                }
                // Returning true tells the capture view to stop responder-chain propagation.
                Task { await viewModel.apply(commands: commands) }
                return true
            }
            .frame(width: 1, height: 1)
        }
        .frame(minWidth: 900, minHeight: 600, alignment: .topLeading)
        .task {
            await viewModel.onAppear()
        }
    }
}

extension CanvasView {
    private func centerPoint(for node: CanvasNode) -> CGPoint {
        CGPoint(
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }
}
