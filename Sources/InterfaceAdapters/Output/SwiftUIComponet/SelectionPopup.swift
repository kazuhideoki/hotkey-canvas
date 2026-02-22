// Background: Keyboard-first workflows need a reusable modal popup for quick mode and option selection.
// Responsibility: Render a generic, modal selection popup with highlighted option and confirm/dismiss callbacks.
import SwiftUI

/// Reusable option model for `SelectionPopup`.
struct SelectionPopupOption: Equatable, Identifiable {
    let id: String
    let title: String
    let shortcutLabel: String
}

/// Reusable modal popup that allows selecting one option and confirming it immediately.
struct SelectionPopup: View {
    let title: String
    let footerText: String
    let options: [SelectionPopupOption]
    let selectedOptionID: String
    let onSelectOption: (String) -> Void
    let onConfirmOption: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Keep modal semantics while visible.
                }

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                ForEach(options) { option in
                    optionRow(option)
                }
                Text(footerText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 320)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onExitCommand(perform: onDismiss)
    }

    @ViewBuilder
    private func optionRow(_ option: SelectionPopupOption) -> some View {
        Button {
            onSelectOption(option.id)
            onConfirmOption(option.id)
        } label: {
            HStack {
                Text(option.title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(option.shortcutLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        selectedOptionID == option.id
                            ? Color.accentColor.opacity(0.2)
                            : Color(nsColor: .textBackgroundColor).opacity(0.35)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
