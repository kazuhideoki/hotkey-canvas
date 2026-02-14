import AppKit
import Domain
import SwiftUI

public struct CanvasView: View {
    @StateObject private var viewModel: CanvasViewModel
    @State private var editingContext: NodeEditingContext?
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
                .contentShape(Rectangle())

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
                        if editingContext?.nodeID == node.id {
                            NodeTextEditor(
                                text: editingTextBinding(for: node.id),
                                selectAllOnFirstFocus: false,
                                onCommit: {
                                    commitNodeEditing()
                                }
                            )
                            .padding(6)
                        } else {
                            Text(node.text ?? "")
                                .font(.system(size: 14, weight: .medium))
                                .padding(12)
                        }
                    }
                    .frame(
                        width: CGFloat(node.bounds.width),
                        height: CGFloat(node.bounds.height),
                        alignment: .topLeading
                    )
                    .offset(x: CGFloat(node.bounds.x), y: CGFloat(node.bounds.y))
            }

            CanvasHotkeyCaptureView(isEnabled: editingContext == nil) { event in
                let commands = hotkeyTranslator.translate(event)
                guard !commands.isEmpty else {
                    return handleTypingInputStart(event, nodesByID: nodesByID)
                }
                // Returning true tells the capture view to stop responder-chain propagation.
                Task { await viewModel.apply(commands: commands) }
                return true
            }
            .frame(width: 1, height: 1)
            // Keep key capture active without intercepting canvas rendering.
            .allowsHitTesting(false)
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

    private func editingTextBinding(for nodeID: CanvasNodeID) -> Binding<String> {
        Binding(
            get: {
                guard editingContext?.nodeID == nodeID else {
                    return ""
                }
                return editingContext?.text ?? ""
            },
            set: { updatedText in
                guard editingContext?.nodeID == nodeID else {
                    return
                }
                editingContext?.text = updatedText
            }
        )
    }

    private func handleTypingInputStart(
        _ event: NSEvent,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> Bool {
        guard let focusedNodeID = viewModel.focusedNodeID, nodesByID[focusedNodeID] != nil else {
            return false
        }
        guard let typedCharacters = typedCharactersForInputStart(from: event) else {
            return false
        }
        editingContext = NodeEditingContext(
            nodeID: focusedNodeID,
            text: typedCharacters
        )
        return true
    }

    private func typedCharactersForInputStart(from event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        guard flags.isDisjoint(with: disallowed) else {
            return nil
        }

        guard let characters = event.characters, !characters.isEmpty else {
            return nil
        }
        if characters.rangeOfCharacter(from: .controlCharacters) != nil {
            return nil
        }
        return characters
    }

    private func commitNodeEditingIfNeeded() {
        guard let context = editingContext else {
            return
        }
        commitNodeEditing(context)
    }

    private func commitNodeEditing() {
        commitNodeEditingIfNeeded()
    }

    private func commitNodeEditing(_ context: NodeEditingContext) {
        editingContext = nil
        Task {
            await viewModel.commitNodeText(nodeID: context.nodeID, text: context.text)
        }
    }
}

private struct NodeEditingContext: Equatable {
    let nodeID: CanvasNodeID
    var text: String
}
