// Background: Canvas search requires deterministic hit ordering and keyboard-only navigation in the view layer.
// Responsibility: Provide inline search state transitions, match navigation, and text highlight helpers.
import AppKit
import Domain
import Foundation
import SwiftUI

struct CanvasSearchMatch: Equatable {
    let nodeID: CanvasNodeID
    let location: Int
    let length: Int
}

enum CanvasSearchDirection {
    case forward
    case backward
}

enum CanvasSearchNavigator {
    static func matches(query: String, nodes: [CanvasNode]) -> [CanvasSearchMatch] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }
        var orderedMatches: [CanvasSearchMatch] = []
        for node in orderedNodes(nodes) {
            let text = node.text ?? ""
            let nsText = text as NSString
            guard nsText.length > 0 else {
                continue
            }
            var searchLocation = 0
            while searchLocation < nsText.length {
                let searchRange = NSRange(location: searchLocation, length: nsText.length - searchLocation)
                let foundRange = nsText.range(
                    of: normalizedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                )
                guard foundRange.location != NSNotFound else {
                    break
                }
                orderedMatches.append(
                    CanvasSearchMatch(
                        nodeID: node.id,
                        location: foundRange.location,
                        length: foundRange.length
                    )
                )
                searchLocation = foundRange.location + max(foundRange.length, 1)
            }
        }
        return orderedMatches
    }

    static func nextMatch(
        currentMatch: CanvasSearchMatch?,
        matches: [CanvasSearchMatch],
        direction: CanvasSearchDirection
    ) -> CanvasSearchMatch? {
        guard !matches.isEmpty else {
            return nil
        }
        guard let currentMatch, let currentIndex = matches.firstIndex(of: currentMatch) else {
            switch direction {
            case .forward:
                return matches.first
            case .backward:
                return matches.last
            }
        }

        let count = matches.count
        switch direction {
        case .forward:
            return matches[(currentIndex + 1) % count]
        case .backward:
            return matches[(currentIndex - 1 + count) % count]
        }
    }

    private static func orderedNodes(_ nodes: [CanvasNode]) -> [CanvasNode] {
        nodes.sorted { lhs, rhs in
            if lhs.bounds.y != rhs.bounds.y {
                return lhs.bounds.y < rhs.bounds.y
            }
            if lhs.bounds.x != rhs.bounds.x {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}

extension CanvasView {
    func openSearch() {
        isCommandPalettePresented = false
        dismissConnectNodeSelection()
        isAddNodeModePopupPresented = false
        isSearchPresented = true
    }

    func closeSearch(displayNodes: [CanvasNode]) {
        let nodeIDToFocus = searchFocusedMatch?.nodeID
        isSearchPresented = false
        searchQuery = ""
        searchFocusedMatch = nil

        guard
            let nodeIDToFocus,
            displayNodes.contains(where: { $0.id == nodeIDToFocus })
        else {
            return
        }
        Task {
            await viewModel.apply(commands: [.focusNode(nodeIDToFocus)])
        }
    }

    func moveSearchFocus(direction: CanvasSearchDirection, displayNodes: [CanvasNode]) {
        let matches = CanvasSearchNavigator.matches(query: searchQuery, nodes: displayNodes)
        guard
            let nextMatch = CanvasSearchNavigator.nextMatch(
                currentMatch: searchFocusedMatch,
                matches: matches,
                direction: direction
            )
        else {
            searchFocusedMatch = nil
            return
        }
        searchFocusedMatch = nextMatch
        centerViewport(on: nextMatch.nodeID, displayNodes: displayNodes)
    }

    func centerViewport(on nodeID: CanvasNodeID, displayNodes: [CanvasNode]) {
        guard let node = displayNodes.first(where: { $0.id == nodeID }) else {
            return
        }
        cameraAnchorPoint = centerPoint(for: node)
        hasInitializedCameraAnchor = true
        manualPanOffset = .zero
    }

    func onSearchQueryChange(displayNodes: [CanvasNode]) {
        let matches = CanvasSearchNavigator.matches(query: searchQuery, nodes: displayNodes)
        guard
            let searchFocusedMatch,
            matches.contains(searchFocusedMatch)
        else {
            self.searchFocusedMatch = nil
            return
        }
    }

    func highlightedNodeText(for node: CanvasNode) -> AttributedString {
        let text = node.text ?? ""
        var attributedText = AttributedString(text)
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return attributedText
        }

        let nodeMatches =
            CanvasSearchNavigator
            .matches(query: normalizedQuery, nodes: [node])
            .filter { $0.nodeID == node.id && $0.length > 0 }
        guard !nodeMatches.isEmpty else {
            return attributedText
        }

        let nsText = text as NSString
        for match in nodeMatches {
            guard match.location >= 0, match.location + match.length <= nsText.length else {
                continue
            }
            let nsRange = NSRange(location: match.location, length: match.length)
            guard
                let stringRange = Range(nsRange, in: text),
                let attributedRange = Range(stringRange, in: attributedText)
            else {
                continue
            }
            let isFocused = searchFocusedMatch == match
            attributedText[attributedRange].backgroundColor =
                isFocused
                ? Color(nsColor: .systemYellow)
                : Color(nsColor: NSColor.systemYellow.withAlphaComponent(0.6))
        }
        return attributedText
    }

    func hasSearchMatches(in node: CanvasNode) -> Bool {
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return false
        }
        return CanvasSearchNavigator.matches(query: normalizedQuery, nodes: [node]).isEmpty == false
    }

    @ViewBuilder
    func searchPanel(displayNodes: [CanvasNode]) -> some View {
        if isSearchPresented {
            VStack(alignment: .leading, spacing: 8) {
                Text("Find")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                CanvasSearchTextField(
                    text: $searchQuery,
                    onSubmitForward: {
                        moveSearchFocus(direction: .forward, displayNodes: displayNodes)
                    },
                    onSubmitBackward: {
                        moveSearchFocus(direction: .backward, displayNodes: displayNodes)
                    },
                    onCancel: {
                        closeSearch(displayNodes: displayNodes)
                    }
                )
                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let matches = CanvasSearchNavigator.matches(query: searchQuery, nodes: displayNodes)
                    let statusText = searchStatusText(matches: matches)
                    if let statusText {
                        Text(statusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 280)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(styleColor(.separator), lineWidth: 1)
            )
            .padding(.top, 20)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            .zIndex(13)
        }
    }

    private func searchStatusText(matches: [CanvasSearchMatch]) -> String? {
        guard !matches.isEmpty else {
            return "No matches"
        }
        guard let searchFocusedMatch, let index = matches.firstIndex(of: searchFocusedMatch) else {
            return "0 / \(matches.count)"
        }
        return "\(index + 1) / \(matches.count)"
    }

    func isSearchFocusedNode(_ nodeID: CanvasNodeID) -> Bool {
        searchFocusedMatch?.nodeID == nodeID
    }
}
