// Background: Edge labels need inline editing and lightweight rendering without introducing a rich text mode.
// Responsibility: Render world-space edge labels and provide screen-space inline editing UI.
import AppKit
import Domain
import SwiftUI

extension CanvasView {
    struct EdgeLabelPlacementBundleKey: Hashable {
        let firstNodeID: String
        let secondNodeID: String
    }

    private static let edgeLabelMinWidth: CGFloat = 40
    private static let edgeLabelMaxWidth: CGFloat = 320
    private static let edgeLabelHorizontalPadding: CGFloat = 6
    private static let edgeLabelVerticalPadding: CGFloat = 3
    private static let edgeLabelCornerRadius: CGFloat = 6
    private static let edgeLabelCollisionPadding: CGFloat = 4
    private static let edgeLabelCollisionSearchLevels = 6

    struct EdgeLabelPlacementCandidate: Equatable {
        let edgeID: CanvasEdgeID
        let baseCenter: CGPoint
        let tangent: CGVector
        let normal: CGVector
        let size: CGSize
        let bundleKey: EdgeLabelPlacementBundleKey
        let bundleSortValue: Double
        let tangentOffsetLimit: CGFloat
    }

    @ViewBuilder
    func edgeLabelOverlay(
        edge: CanvasEdge,
        placementCenter: CGPoint?
    ) -> some View {
        let isEditing = edgeEditingContext?.edgeID == edge.id
        let label = edge.label ?? ""
        if !isEditing, !label.isEmpty, let labelCenter = placementCenter {
            staticEdgeLabelOverlay(
                label: label,
                labelCenter: labelCenter,
                fieldWidth: edgeLabelWidth(for: label)
            )
        } else {
            EmptyView()
        }
    }
}

extension CanvasView {
    @ViewBuilder
    func editingEdgeLabelOverlay(
        edge: CanvasEdge,
        labelCenter: CGPoint,
        fieldWidth: CGFloat,
        viewportZoomScale: Double
    ) -> some View {
        let zoomScale = max(CGFloat(viewportZoomScale), 0.0001)
        NodeTextEditor(
            text: editingEdgeLabelBinding(for: edge.id),
            nodeWidth: fieldWidth * zoomScale,
            zoomScale: viewportZoomScale,
            contentScale: edgeLabelEditorContentScale(),
            style: nodeTextStyle,
            contentAlignment: .topLeading,
            selectAllOnFirstFocus: false,
            initialCursorPlacement: edgeEditingContext?.initialCursorPlacement ?? .end,
            initialTypingEvent: edgeEditingContext?.initialTypingEvent,
            onLayoutMetricsChange: { metrics in
                updateEdgeEditingLayout(for: edge.id, metrics: metrics)
            },
            onCommit: {
                commitEdgeEditingIfNeeded()
            },
            onCancel: {
                cancelEdgeEditing()
            }
        )
        .frame(
            width: fieldWidth * zoomScale,
            height: CGFloat(edgeEditingContext?.editorHeight ?? edgeLabelEditorHeight()) * zoomScale
        )
        .padding(.horizontal, Self.edgeLabelHorizontalPadding * zoomScale)
        .padding(.vertical, Self.edgeLabelVerticalPadding * zoomScale)
        .background(styleColor(.textBackground))
        .overlay(edgeLabelBorderOverlay(zoomScale: zoomScale))
        .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius * zoomScale))
        .position(labelCenter)
        .zIndex(5)
    }

    @ViewBuilder
    private func staticEdgeLabelOverlay(
        label: String,
        labelCenter: CGPoint,
        fieldWidth: CGFloat
    ) -> some View {
        Text(label)
            .font(.system(size: edgeLabelFontSize(), weight: .medium))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: fieldWidth, alignment: .leading)
            .padding(.horizontal, Self.edgeLabelHorizontalPadding)
            .padding(.vertical, Self.edgeLabelVerticalPadding)
            .background(styleColor(.textBackground))
            .overlay(edgeLabelBorderOverlay())
            .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
            .position(labelCenter)
            .zIndex(4)
    }

    private func edgeLabelBorderOverlay(zoomScale: CGFloat = 1) -> some View {
        RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius * zoomScale)
            .stroke(styleColor(.separator), lineWidth: zoomScale)
    }

    func edgeLabelPlacementCenters(
        edges: [CanvasEdge],
        context: EdgeRenderContext
    ) -> [CanvasEdgeID: CGPoint] {
        let candidates = edges.compactMap { edge in
            edgeLabelPlacementCandidate(edge: edge, context: context)
        }
        return Self.resolveEdgeLabelPlacements(candidates: candidates)
    }

    func edgeLabelWidth(for label: String) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(),
            weight: .medium
        )
        let measuredWidth =
            label
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                (String(line) as NSString).size(withAttributes: [.font: font]).width
            }
            .max() ?? 0
        let widthWithPadding = measuredWidth + (Self.edgeLabelHorizontalPadding * 2) + 12
        return min(max(widthWithPadding, Self.edgeLabelMinWidth), Self.edgeLabelMaxWidth)
    }

    private func edgeLabelEditorHeight() -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(),
            weight: .medium
        )
        let contentHeight = font.ascender - font.descender + font.leading
        let insets =
            nodeTextStyle.textContainerInset
            * edgeLabelEditorContentScale()
            * 2
        return max(contentHeight + insets, 14)
    }

    private func edgeLabelEditorContentScale() -> Double {
        let baseFontSize = nodeTextStyle.fontSize
        guard baseFontSize > 0 else {
            return 1
        }
        return Double(edgeLabelFontSize() / baseFontSize)
    }

    private func edgeLabelFontSize() -> CGFloat {
        11
    }

    private func edgeLabelPlacementCandidate(
        edge: CanvasEdge,
        context: EdgeRenderContext
    ) -> EdgeLabelPlacementCandidate? {
        let isEditing = edgeEditingContext?.edgeID == edge.id
        let label = isEditing ? (edgeEditingContext?.label ?? "") : (edge.label ?? "")
        guard isEditing || !label.isEmpty else {
            return nil
        }

        let areaID = context.areaIDByNodeID[edge.fromNodeID]
        let edgeShapeStyle = areaID.flatMap { context.areaEdgeShapeStyleByID[$0] } ?? .curved
        let editingMode = areaID.flatMap { context.areaEditingModeByID[$0] }
        let routingStyle: CanvasEdgeRouting.RoutingStyle = editingMode == .tree ? .treeSimple : .adaptive
        let nodeAvoidanceEnabled = editingMode != .tree
        let branchCoordinateByParentAndDirection =
            routingStyle == .treeSimple
            ? context.treeBranchCoordinateByParentAndDirection
            : context.branchCoordinateByParentAndDirection
        guard
            let anchor = CanvasEdgeRouting.labelAnchor(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                edgeShapeStyle: edgeShapeStyle,
                routingStyle: routingStyle,
                nodeAvoidanceEnabled: nodeAvoidanceEnabled
            )
        else {
            return nil
        }

        let fieldWidth = edgeLabelWidth(for: label)
        let labelHeight =
            isEditing
            ? CGFloat(edgeEditingContext?.editorHeight ?? edgeLabelEditorHeight())
                + (Self.edgeLabelVerticalPadding * 2)
            : edgeLabelDisplayHeight(for: label, width: fieldWidth)

        return EdgeLabelPlacementCandidate(
            edgeID: edge.id,
            baseCenter: anchor.point,
            tangent: normalized(vector: anchor.tangent) ?? CGVector(dx: 1, dy: 0),
            normal: normalized(vector: anchor.normal) ?? CGVector(dx: 0, dy: -1),
            size: CGSize(width: fieldWidth, height: labelHeight),
            bundleKey: edgeLabelBundleKey(for: edge),
            bundleSortValue: edgeLabelBundleSortValue(for: edge.id, context: context),
            tangentOffsetLimit: edgeLabelTangentOffsetLimit(
                anchorCenter: anchor.point,
                edge: edge,
                context: context,
                labelSize: CGSize(width: fieldWidth, height: labelHeight)
            )
        )
    }

    private func edgeLabelDisplayHeight(
        for label: String,
        width: CGFloat
    ) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(),
            weight: .medium
        )
        let constrainedWidth = max(width - (Self.edgeLabelHorizontalPadding * 2), 1)
        let boundingRect = (label as NSString).boundingRect(
            with: CGSize(width: constrainedWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(boundingRect.height) + (Self.edgeLabelVerticalPadding * 2)
    }

    static func resolveEdgeLabelPlacements(
        candidates: [EdgeLabelPlacementCandidate]
    ) -> [CanvasEdgeID: CGPoint] {
        let sortedCandidates = candidates.sorted(by: isPlacementCandidateOrdered)
        var centersByEdgeID: [CanvasEdgeID: CGPoint] = [:]
        var occupiedFrames: [CGRect] = []
        let bundleAdjustedCenters = bundleAdjustedCentersByEdgeID(candidates: sortedCandidates)

        for candidate in sortedCandidates {
            let adjustedBaseCenter = bundleAdjustedCenters[candidate.edgeID] ?? candidate.baseCenter
            let resolvedCenter = resolvedEdgeLabelCenter(
                candidate: candidate,
                adjustedBaseCenter: adjustedBaseCenter,
                occupiedFrames: occupiedFrames
            )
            centersByEdgeID[candidate.edgeID] = resolvedCenter
            occupiedFrames.append(edgeLabelFrame(center: resolvedCenter, size: candidate.size))
        }

        return centersByEdgeID
    }

    private static func resolvedEdgeLabelCenter(
        candidate: EdgeLabelPlacementCandidate,
        adjustedBaseCenter: CGPoint,
        occupiedFrames: [CGRect]
    ) -> CGPoint {
        let step = max(candidate.size.height + Self.edgeLabelCollisionPadding, 18)
        for offsetIndex in placementOffsetIndices(maxLevel: Self.edgeLabelCollisionSearchLevels) {
            let offset = CGFloat(offsetIndex) * step
            let center = CGPoint(
                x: adjustedBaseCenter.x + (candidate.normal.dx * offset),
                y: adjustedBaseCenter.y + (candidate.normal.dy * offset)
            )
            let frame = edgeLabelFrame(center: center, size: candidate.size)
            let hasCollision = occupiedFrames.contains { occupiedFrame in
                frame.insetBy(dx: -Self.edgeLabelCollisionPadding, dy: -Self.edgeLabelCollisionPadding)
                    .intersects(
                        occupiedFrame.insetBy(dx: -Self.edgeLabelCollisionPadding, dy: -Self.edgeLabelCollisionPadding)
                    )
            }
            if !hasCollision {
                return center
            }
        }
        return adjustedBaseCenter
    }

    private static func bundleAdjustedCentersByEdgeID(
        candidates: [EdgeLabelPlacementCandidate]
    ) -> [CanvasEdgeID: CGPoint] {
        let groupedCandidates = Dictionary(grouping: candidates, by: \.bundleKey)
        var centersByEdgeID: [CanvasEdgeID: CGPoint] = [:]

        for groupedBundle in groupedCandidates.values {
            let sortedBundle = groupedBundle.sorted(by: isBundleCandidateOrdered)
            let tangentOffsets = bundleTangentOffsets(for: sortedBundle)
            for (candidate, tangentOffset) in zip(sortedBundle, tangentOffsets) {
                let clampedOffset = max(min(tangentOffset, candidate.tangentOffsetLimit), -candidate.tangentOffsetLimit)
                centersByEdgeID[candidate.edgeID] = CGPoint(
                    x: candidate.baseCenter.x + (candidate.tangent.dx * clampedOffset),
                    y: candidate.baseCenter.y + (candidate.tangent.dy * clampedOffset)
                )
            }
        }

        return centersByEdgeID
    }

    private static func bundleTangentOffsets(for candidates: [EdgeLabelPlacementCandidate]) -> [CGFloat] {
        guard !candidates.isEmpty else {
            return []
        }

        var offsets = Array(repeating: CGFloat(0), count: candidates.count)
        let spacing = { (lhs: EdgeLabelPlacementCandidate, rhs: EdgeLabelPlacementCandidate) in
            max((lhs.size.width / 2) + (rhs.size.width / 2) + (Self.edgeLabelCollisionPadding * 2), 28)
        }

        if candidates.count.isMultiple(of: 2) {
            let leftCenterIndex = (candidates.count / 2) - 1
            let rightCenterIndex = leftCenterIndex + 1
            let centerSpacing = spacing(candidates[leftCenterIndex], candidates[rightCenterIndex])
            offsets[leftCenterIndex] = -centerSpacing / 2
            offsets[rightCenterIndex] = centerSpacing / 2

            if leftCenterIndex > 0 {
                for index in stride(from: leftCenterIndex - 1, through: 0, by: -1) {
                    let nextIndex = index + 1
                    offsets[index] = offsets[nextIndex] - spacing(candidates[index], candidates[nextIndex])
                }
            }
            if rightCenterIndex < candidates.count - 1 {
                for index in (rightCenterIndex + 1)..<candidates.count {
                    let previousIndex = index - 1
                    offsets[index] = offsets[previousIndex] + spacing(candidates[previousIndex], candidates[index])
                }
            }
            return offsets
        }

        let centerIndex = candidates.count / 2
        if centerIndex > 0 {
            for index in stride(from: centerIndex - 1, through: 0, by: -1) {
                let nextIndex = index + 1
                offsets[index] = offsets[nextIndex] - spacing(candidates[index], candidates[nextIndex])
            }
        }
        if centerIndex < candidates.count - 1 {
            for index in (centerIndex + 1)..<candidates.count {
                let previousIndex = index - 1
                offsets[index] = offsets[previousIndex] + spacing(candidates[previousIndex], candidates[index])
            }
        }
        return offsets
    }

    private static func isBundleCandidateOrdered(
        _ lhs: EdgeLabelPlacementCandidate,
        _ rhs: EdgeLabelPlacementCandidate
    ) -> Bool {
        if lhs.bundleSortValue != rhs.bundleSortValue {
            return lhs.bundleSortValue < rhs.bundleSortValue
        }
        return lhs.edgeID.rawValue < rhs.edgeID.rawValue
    }

    private static func placementOffsetIndices(maxLevel: Int) -> [Int] {
        var offsets: [Int] = [0]
        guard maxLevel > 0 else {
            return offsets
        }
        for level in 1...maxLevel {
            offsets.append(level)
            offsets.append(-level)
        }
        return offsets
    }

    private static func edgeLabelFrame(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - (size.width / 2),
            y: center.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    private func edgeLabelBundleKey(for edge: CanvasEdge) -> EdgeLabelPlacementBundleKey {
        let nodeIDs = [edge.fromNodeID.rawValue, edge.toNodeID.rawValue].sorted()
        return EdgeLabelPlacementBundleKey(
            firstNodeID: nodeIDs[0],
            secondNodeID: nodeIDs[1]
        )
    }

    private func edgeLabelBundleSortValue(
        for edgeID: CanvasEdgeID,
        context: EdgeRenderContext
    ) -> Double {
        let laneOffsets = context.laneOffsetsByEdgeID[edgeID] ?? .zero
        return (laneOffsets.start + laneOffsets.end) / 2
    }

    private func edgeLabelTangentOffsetLimit(
        anchorCenter: CGPoint,
        edge: CanvasEdge,
        context: EdgeRenderContext,
        labelSize: CGSize
    ) -> CGFloat {
        let areaID = context.areaIDByNodeID[edge.fromNodeID]
        let editingMode = areaID.flatMap { context.areaEditingModeByID[$0] }
        let routingStyle: CanvasEdgeRouting.RoutingStyle = editingMode == .tree ? .treeSimple : .adaptive
        let branchCoordinateByParentAndDirection =
            routingStyle == .treeSimple
            ? context.treeBranchCoordinateByParentAndDirection
            : context.branchCoordinateByParentAndDirection
        guard
            let geometry = CanvasEdgeRouting.routeGeometry(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                routingStyle: routingStyle
            )
        else {
            return 0
        }
        let start = CGPoint(x: geometry.startX, y: geometry.startY)
        let end = CGPoint(x: geometry.endX, y: geometry.endY)
        let minEndpointDistance = min(distance(from: anchorCenter, to: start), distance(from: anchorCenter, to: end))
        let contentInset = max(labelSize.width / 2, labelSize.height / 2) + 12
        return max(minEndpointDistance - contentInset, 0)
    }

    private static func isPlacementCandidateOrdered(
        _ lhs: EdgeLabelPlacementCandidate,
        _ rhs: EdgeLabelPlacementCandidate
    ) -> Bool {
        if lhs.bundleKey.firstNodeID != rhs.bundleKey.firstNodeID {
            return lhs.bundleKey.firstNodeID < rhs.bundleKey.firstNodeID
        }
        if lhs.bundleKey.secondNodeID != rhs.bundleKey.secondNodeID {
            return lhs.bundleKey.secondNodeID < rhs.bundleKey.secondNodeID
        }
        if lhs.bundleSortValue != rhs.bundleSortValue {
            return lhs.bundleSortValue < rhs.bundleSortValue
        }
        if lhs.baseCenter.x != rhs.baseCenter.x {
            return lhs.baseCenter.x < rhs.baseCenter.x
        }
        if lhs.baseCenter.y != rhs.baseCenter.y {
            return lhs.baseCenter.y < rhs.baseCenter.y
        }
        return lhs.edgeID.rawValue < rhs.edgeID.rawValue
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt((dx * dx) + (dy * dy))
    }

    private func normalized(vector: CGVector) -> CGVector? {
        let length = sqrt((vector.dx * vector.dx) + (vector.dy * vector.dy))
        guard length > 0.001 else {
            return nil
        }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}
