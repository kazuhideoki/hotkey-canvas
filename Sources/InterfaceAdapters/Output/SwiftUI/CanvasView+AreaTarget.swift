// Background: Area target mode needs a distinct non-rectangular visual focus ring around area membership.
// Responsibility: Render area-focus outline and resolve area outline geometry from current visible nodes.
import Domain
import SwiftUI

extension CanvasView {
    func areaFocusOverlay(
        displayNodes: [CanvasNode],
        viewportSize: CGSize,
        effectiveOffset: CGSize
    ) -> some View {
        guard operationTargetKind == .area else { return AnyView(EmptyView()) }
        guard let focusedAreaID = viewModel.focusedAreaID else { return AnyView(EmptyView()) }

        let nodesByID = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })
        let areaNodeIDs = Set(
            displayNodes
                .filter { viewModel.areaIDByNodeID[$0.id] == focusedAreaID }
                .map(\.id)
        )
        let graph = CanvasGraph(nodesByID: nodesByID)
        guard
            let outline = CanvasAreaLayoutService.makeAreaOutline(
                nodeIDs: areaNodeIDs,
                in: graph,
                shapeKind: .convexHull
            )
        else { return AnyView(EmptyView()) }

        let areaPath = areaOutlinePath(outline: outline, padding: 18)
            .applying(
                CanvasViewportTransform.affineTransform(
                    viewportSize: viewportSize,
                    zoomScale: zoomScale,
                    effectiveOffset: effectiveOffset
                )
            )

        return AnyView(
            areaPath
                .stroke(
                    styleColor(.accent).opacity(0.85),
                    style: StrokeStyle(lineWidth: 2, lineJoin: .round)
                )
        )
    }

    private func areaOutlinePath(outline: CanvasNodeArea, padding: Double) -> Path {
        switch outline.shape {
        case .rectangle:
            let rect = CGRect(
                x: outline.bounds.minX - padding,
                y: outline.bounds.minY - padding,
                width: outline.bounds.width + (padding * 2),
                height: outline.bounds.height + (padding * 2)
            )
            return Path(rect)
        case .convexHull(let vertices):
            let paddedVertices = paddedHullVertices(vertices: vertices, padding: padding)
            guard let first = paddedVertices.first else {
                let rect = CGRect(
                    x: outline.bounds.minX - padding,
                    y: outline.bounds.minY - padding,
                    width: outline.bounds.width + (padding * 2),
                    height: outline.bounds.height + (padding * 2)
                )
                return Path(rect)
            }
            var path = Path()
            path.move(to: CGPoint(x: first.x, y: first.y))
            for vertex in paddedVertices.dropFirst() {
                path.addLine(to: CGPoint(x: vertex.x, y: vertex.y))
            }
            path.closeSubpath()
            return path
        }
    }

    private func paddedHullVertices(vertices: [CanvasPoint], padding: Double) -> [CanvasPoint] {
        guard !vertices.isEmpty else {
            return []
        }
        let centerX = vertices.map(\.x).reduce(0, +) / Double(vertices.count)
        let centerY = vertices.map(\.y).reduce(0, +) / Double(vertices.count)
        let epsilon = 1e-9

        return vertices.map { vertex in
            let deltaX = vertex.x - centerX
            let deltaY = vertex.y - centerY
            let length = (deltaX * deltaX + deltaY * deltaY).squareRoot()
            guard length > epsilon else {
                return vertex
            }
            return CanvasPoint(
                x: vertex.x + ((deltaX / length) * padding),
                y: vertex.y + ((deltaY / length) * padding)
            )
        }
    }
}
