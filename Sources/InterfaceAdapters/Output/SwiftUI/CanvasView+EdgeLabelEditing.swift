// Background: Edge labels need inline editing and lightweight rendering without introducing a rich text mode.
// Responsibility: Render edge labels near the route center and provide keyboard-first editing UI.
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
        context: EdgeRenderContext,
        placementCenter: CGPoint?
    ) -> some View {
        let isEditing = edgeEditingContext?.edgeID == edge.id
        let label = isEditing ? (edgeEditingContext?.label ?? "") : (edge.label ?? "")
<<<<<<< HEAD
        if isEditing || !label.isEmpty,
            let labelCenter = edgeLabelScreenCenter(edge: edge, context: context)
        {
            let fieldWidth = edgeLabelWidth(for: label, zoomScale: context.zoomScale)
            if isEditing {
                edgeLabelEditorOverlay(
                    edgeID: edge.id,
                    context: context,
                    fieldWidth: fieldWidth,
                    labelCenter: labelCenter
                )
            } else {
                edgeLabelTextOverlay(
                    label: label,
                    context: context,
                    fieldWidth: fieldWidth,
                    labelCenter: labelCenter
=======
        if isEditing || !label.isEmpty, let labelCenter = placementCenter {
            let fieldWidth = edgeLabelWidth(for: label, zoomScale: context.zoomScale)
            if isEditing {
                editingEdgeLabelOverlay(
                    edge: edge,
                    context: context,
                    labelCenter: labelCenter,
                    fieldWidth: fieldWidth
                )
            } else {
                staticEdgeLabelOverlay(
                    label: label,
                    context: context,
                    labelCenter: labelCenter,
                    fieldWidth: fieldWidth
>>>>>>> main
                )
            }
        } else {
            EmptyView()
        }
    }
}

extension CanvasView {
    @ViewBuilder
<<<<<<< HEAD
    private func edgeLabelEditorOverlay(
        edgeID: CanvasEdgeID,
        context: EdgeRenderContext,
        fieldWidth: CGFloat,
        labelCenter: CGPoint
    ) -> some View {
        NodeTextEditor(
            text: editingEdgeLabelBinding(for: edgeID),
            nodeWidth: fieldWidth,
            zoomScale: context.zoomScale,
            contentScale: edgeLabelEditorContentScale(zoomScale: context.zoomScale),
            style: nodeTextStyle,
            contentAlignment: .topLeading,
            selectAllOnFirstFocus: false,
            initialCursorPlacement: edgeEditingContext?.initialCursorPlacement ?? .end,
            initialTypingEvent: edgeEditingContext?.initialTypingEvent,
            onLayoutMetricsChange: { metrics in
                updateEdgeEditingLayout(for: edgeID, metrics: metrics)
            },
            onCommit: {
                commitEdgeEditingIfNeeded()
            },
            onCancel: {
                cancelEdgeEditing()
            }
        )
        .frame(
            width: fieldWidth,
            height: CGFloat(
                edgeEditingContext?.editorHeight ?? edgeLabelEditorHeight(zoomScale: context.zoomScale))
        )
        .padding(.horizontal, Self.edgeLabelHorizontalPadding)
        .padding(.vertical, Self.edgeLabelVerticalPadding)
        .background(styleColor(.textBackground))
        .overlay(
            RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius)
                .stroke(styleColor(.separator), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
        .position(labelCenter)
        .zIndex(5)
    }

    @ViewBuilder
    private func edgeLabelTextOverlay(
        label: String,
        context: EdgeRenderContext,
        fieldWidth: CGFloat,
        labelCenter: CGPoint
    ) -> some View {
        Text(label)
            .font(
                .system(
                    size: max(11 * CGFloat(context.zoomScale), 9),
                    weight: .medium
                )
            )
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: fieldWidth, alignment: .leading)
            .padding(.horizontal, Self.edgeLabelHorizontalPadding)
            .padding(.vertical, Self.edgeLabelVerticalPadding)
            .background(styleColor(.textBackground))
            .overlay(
                RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius)
                    .stroke(styleColor(.separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
            .position(labelCenter)
            .zIndex(4)
    }

    private func edgeLabelScreenCenter(
=======
    private func editingEdgeLabelOverlay(
>>>>>>> main
        edge: CanvasEdge,
        context: EdgeRenderContext,
        labelCenter: CGPoint,
        fieldWidth: CGFloat
    ) -> some View {
        NodeTextEditor(
            text: editingEdgeLabelBinding(for: edge.id),
            nodeWidth: fieldWidth,
            zoomScale: context.zoomScale,
            contentScale: edgeLabelEditorContentScale(zoomScale: context.zoomScale),
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
            width: fieldWidth,
            height: CGFloat(edgeEditingContext?.editorHeight ?? edgeLabelEditorHeight(zoomScale: context.zoomScale))
        )
        .padding(.horizontal, Self.edgeLabelHorizontalPadding)
        .padding(.vertical, Self.edgeLabelVerticalPadding)
        .background(styleColor(.textBackground))
        .overlay(edgeLabelBorderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
        .position(labelCenter)
        .zIndex(5)
    }

    @ViewBuilder
    private func staticEdgeLabelOverlay(
        label: String,
        context: EdgeRenderContext,
        labelCenter: CGPoint,
        fieldWidth: CGFloat
    ) -> some View {
        Text(label)
            .font(.system(size: max(11 * CGFloat(context.zoomScale), 9), weight: .medium))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: fieldWidth, alignment: .leading)
            .padding(.horizontal, Self.edgeLabelHorizontalPadding)
            .padding(.vertical, Self.edgeLabelVerticalPadding)
            .background(styleColor(.textBackground))
            .overlay(edgeLabelBorderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius))
            .position(labelCenter)
            .zIndex(4)
    }

    private var edgeLabelBorderOverlay: some View {
        RoundedRectangle(cornerRadius: Self.edgeLabelCornerRadius)
            .stroke(styleColor(.separator), lineWidth: 1)
    }

    func edgeLabelPlacementCenters(
        edges: [CanvasEdge],
        context: EdgeRenderContext
    ) -> [CanvasEdgeID: CGPoint] {
        let transform = CanvasViewportTransform.affineTransform(
            viewportSize: context.viewportSize,
            zoomScale: context.zoomScale,
            effectiveOffset: context.cameraOffset
        )
        let candidates = edges.compactMap { edge in
            edgeLabelPlacementCandidate(
                edge: edge,
                context: context,
                transform: transform
            )
        }
        return Self.resolveEdgeLabelPlacements(candidates: candidates)
    }

    private func edgeLabelWidth(for label: String, zoomScale: Double) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(zoomScale: zoomScale),
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

    private func edgeLabelEditorHeight(zoomScale: Double) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(zoomScale: zoomScale),
            weight: .medium
        )
        // Keep editing height to one line so edge label editor remains compact.
        let contentHeight = font.ascender - font.descender + font.leading
        let insets =
            nodeTextStyle.textContainerInset
            * max(CGFloat(zoomScale), 0.0001)
            * edgeLabelEditorContentScale(zoomScale: zoomScale)
            * 2
        return max(contentHeight + insets, 14)
    }

    private func edgeLabelEditorContentScale(zoomScale: Double) -> Double {
        let baseZoomScale = max(CGFloat(zoomScale), 0.0001)
        let baseFontSize = nodeTextStyle.fontSize * baseZoomScale
        guard baseFontSize > 0 else {
            return 1
        }
        return Double(edgeLabelFontSize(zoomScale: zoomScale) / baseFontSize)
    }

    private func edgeLabelFontSize(zoomScale: Double) -> CGFloat {
        max(11 * CGFloat(zoomScale), 9)
    }

    private func edgeLabelPlacementCandidate(
        edge: CanvasEdge,
        context: EdgeRenderContext,
        transform: CGAffineTransform
    ) -> EdgeLabelPlacementCandidate? {
        let isEditing = edgeEditingContext?.edgeID == edge.id
        let label = isEditing ? (edgeEditingContext?.label ?? "") : (edge.label ?? "")
        guard isEditing || !label.isEmpty else {
            return nil
        }

        let areaID = context.areaIDByNodeID[edge.fromNodeID]
        let edgeShapeStyle = areaID.flatMap { context.areaEdgeShapeStyleByID[$0] } ?? .curved
        guard
            let anchor = CanvasEdgeRouting.labelAnchor(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: context.branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                edgeShapeStyle: edgeShapeStyle
            )
        else {
            return nil
        }

        let fieldWidth = edgeLabelWidth(for: label, zoomScale: context.zoomScale)
        let labelHeight =
            isEditing
            ? CGFloat(edgeEditingContext?.editorHeight ?? edgeLabelEditorHeight(zoomScale: context.zoomScale))
                + (Self.edgeLabelVerticalPadding * 2)
            : edgeLabelDisplayHeight(for: label, width: fieldWidth, zoomScale: context.zoomScale)
        let transformedNormal = CGVector(
            dx: (anchor.normal.dx * transform.a) + (anchor.normal.dy * transform.c),
            dy: (anchor.normal.dx * transform.b) + (anchor.normal.dy * transform.d)
        )
        let transformedTangent = CGVector(
            dx: (anchor.tangent.dx * transform.a) + (anchor.tangent.dy * transform.c),
            dy: (anchor.tangent.dx * transform.b) + (anchor.tangent.dy * transform.d)
        )
        return EdgeLabelPlacementCandidate(
            edgeID: edge.id,
            baseCenter: anchor.point.applying(transform),
            tangent: normalized(vector: transformedTangent) ?? CGVector(dx: 1, dy: 0),
            normal: normalized(vector: transformedNormal) ?? CGVector(dx: 0, dy: -1),
            size: CGSize(width: fieldWidth, height: labelHeight),
            bundleKey: edgeLabelBundleKey(for: edge),
            bundleSortValue: edgeLabelBundleSortValue(for: edge.id, context: context),
            tangentOffsetLimit: edgeLabelTangentOffsetLimit(
                anchorCenter: anchor.point.applying(transform),
                edge: edge,
                context: context,
                transform: transform,
                labelSize: CGSize(width: fieldWidth, height: labelHeight)
            )
        )
    }

    private func edgeLabelDisplayHeight(
        for label: String,
        width: CGFloat,
        zoomScale: Double
    ) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: edgeLabelFontSize(zoomScale: zoomScale),
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
        transform: CGAffineTransform,
        labelSize: CGSize
    ) -> CGFloat {
        guard
            let geometry = CanvasEdgeRouting.routeGeometry(
                for: edge,
                nodesByID: context.nodesByID,
                branchCoordinateByParentAndDirection: context.branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: context.laneOffsetsByEdgeID
            )
        else {
            return 0
        }
        let start = CGPoint(x: geometry.startX, y: geometry.startY).applying(transform)
        let end = CGPoint(x: geometry.endX, y: geometry.endY).applying(transform)
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
