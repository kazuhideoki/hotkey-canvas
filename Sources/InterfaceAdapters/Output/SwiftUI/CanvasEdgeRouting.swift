// Background: Straight center-to-center edges overlap sibling nodes as child counts grow.
// Responsibility: Compute side-anchored branched routes so parent-child edges remain readable.
import Domain
import SwiftUI

/// Computes MindNode-like edge routes with a shared branch axis per parent node.
enum CanvasEdgeRouting {
    private static let minimumBranchGap: Double = 12
    private static let maximumBranchOffset: Double = 72
    private static let minimumBranchOffset: Double = 24
    private static let minimumLegLength: Double = 6
    private static let defaultCornerRadius: Double = 14

    /// Geometric route information used to build a rounded edge path.
    struct RouteGeometry: Equatable {
        let startX: Double
        let startY: Double
        let branchX: Double
        let endX: Double
        let endY: Double
    }

    /// Parent+direction key used for storing per-side branch columns.
    struct BranchKey: Hashable {
        let parentNodeID: CanvasNodeID
        let direction: Int
    }

    /// Returns the shared branch x-position for each parent node.
    /// - Parameters:
    ///   - edges: Graph edges to route.
    ///   - nodesByID: Node lookup used for geometric calculations.
    /// - Returns: Mapping from parent node id to branch x-position in canvas coordinates.
    static func branchXByParentAndDirection(
        edges: [CanvasEdge],
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> [BranchKey: Double] {
        let edgesByParent = Dictionary(grouping: edges, by: \.fromNodeID)
        var result: [BranchKey: Double] = [:]

        for (parentID, parentEdges) in edgesByParent {
            guard let parentNode = nodesByID[parentID] else {
                continue
            }
            for direction in [-1.0, 1.0] {
                let directionalEdges = parentEdges.filter { edge in
                    guard let childNode = nodesByID[edge.toNodeID] else {
                        return false
                    }
                    return horizontalDirection(parentNode: parentNode, childNode: childNode) == direction
                }
                guard !directionalEdges.isEmpty else {
                    continue
                }

                let exitX = edgeExitX(for: parentNode, direction: direction)
                let childEntryXValues = directionalEdges.compactMap { edge -> Double? in
                    guard let childNode = nodesByID[edge.toNodeID] else {
                        return nil
                    }
                    return edgeEntryX(for: childNode, direction: direction)
                }
                guard !childEntryXValues.isEmpty else {
                    continue
                }

                let closestChildEntryX =
                    if direction > 0 {
                        childEntryXValues.min() ?? exitX
                    } else {
                        childEntryXValues.max() ?? exitX
                    }
                let available = abs(closestChildEntryX - exitX)
                let offset = max(
                    minimumBranchOffset,
                    min(maximumBranchOffset, available * 0.45)
                )
                let baseBranchX = exitX + (direction * offset)
                let constrainedBranchX = constrainBranchX(
                    baseBranchX,
                    startX: exitX,
                    endX: closestChildEntryX
                )
                let key = BranchKey(parentNodeID: parentID, direction: direction > 0 ? 1 : -1)
                result[key] = constrainedBranchX
            }
        }

        return result
    }

    /// Builds a rounded route path for a single edge.
    /// - Parameters:
    ///   - edge: Edge to route.
    ///   - nodesByID: Node lookup for endpoint geometry.
    ///   - branchXByParent: Shared branch x-position per parent id.
    /// - Returns: Routed path or nil when endpoints are missing.
    static func path(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchXByParentAndDirection: [BranchKey: Double]
    ) -> Path? {
        guard
            let geometry = routeGeometry(
                for: edge,
                nodesByID: nodesByID,
                branchXByParentAndDirection: branchXByParentAndDirection
            )
        else {
            return nil
        }

        return Path { path in
            let start = CGPoint(x: geometry.startX, y: geometry.startY)
            let end = CGPoint(x: geometry.endX, y: geometry.endY)
            path.move(to: start)

            let horizontal1 = abs(geometry.branchX - geometry.startX)
            let horizontal2 = abs(geometry.endX - geometry.branchX)
            let vertical = abs(geometry.endY - geometry.startY)
            let cornerRadius = min(
                defaultCornerRadius,
                horizontal1 / 2,
                horizontal2 / 2,
                vertical / 2
            )

            guard cornerRadius > 0 else {
                path.addLine(to: end)
                return
            }

            let xSignToBranch: Double = geometry.branchX >= geometry.startX ? 1 : -1
            let ySignToEnd: Double = geometry.endY >= geometry.startY ? 1 : -1
            let xSignToEnd: Double = geometry.endX >= geometry.branchX ? 1 : -1

            path.addLine(
                to: CGPoint(
                    x: geometry.branchX - (xSignToBranch * cornerRadius),
                    y: geometry.startY
                )
            )
            path.addQuadCurve(
                to: CGPoint(
                    x: geometry.branchX,
                    y: geometry.startY + (ySignToEnd * cornerRadius)
                ),
                control: CGPoint(x: geometry.branchX, y: geometry.startY)
            )
            path.addLine(
                to: CGPoint(
                    x: geometry.branchX,
                    y: geometry.endY - (ySignToEnd * cornerRadius)
                )
            )
            path.addQuadCurve(
                to: CGPoint(
                    x: geometry.branchX + (xSignToEnd * cornerRadius),
                    y: geometry.endY
                ),
                control: CGPoint(x: geometry.branchX, y: geometry.endY)
            )
            path.addLine(to: end)
        }
    }

    /// Computes route geometry for one edge.
    /// - Parameters:
    ///   - edge: Edge to route.
    ///   - nodesByID: Node lookup for endpoint geometry.
    ///   - branchXByParent: Shared branch x-position per parent id.
    /// - Returns: Route geometry or nil when endpoints are missing.
    static func routeGeometry(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchXByParentAndDirection: [BranchKey: Double]
    ) -> RouteGeometry? {
        guard
            let parentNode = nodesByID[edge.fromNodeID],
            let childNode = nodesByID[edge.toNodeID]
        else {
            return nil
        }

        let direction = horizontalDirection(parentNode: parentNode, childNode: childNode)
        let directionKey = BranchKey(parentNodeID: edge.fromNodeID, direction: direction > 0 ? 1 : -1)
        let startX = edgeExitX(for: parentNode, direction: direction)
        let endX = edgeEntryX(for: childNode, direction: direction)
        let startY = parentNode.bounds.y + (parentNode.bounds.height / 2)
        let endY = childNode.bounds.y + (childNode.bounds.height / 2)
        let branchX = constrainBranchX(
            branchXByParentAndDirection[directionKey] ?? (startX + (direction * minimumBranchOffset)),
            startX: startX,
            endX: endX
        )

        return RouteGeometry(
            startX: startX,
            startY: startY,
            branchX: branchX,
            endX: endX,
            endY: endY
        )
    }
}

extension CanvasEdgeRouting {
    private static func horizontalDirection(
        parentNode: CanvasNode,
        childNode: CanvasNode
    ) -> Double {
        let childCenterX = childNode.bounds.x + (childNode.bounds.width / 2)
        let parentCenterX = parentNode.bounds.x + (parentNode.bounds.width / 2)
        return childCenterX >= parentCenterX ? 1 : -1
    }

    private static func edgeExitX(for node: CanvasNode, direction: Double) -> Double {
        direction >= 0 ? node.bounds.x + node.bounds.width : node.bounds.x
    }

    private static func edgeEntryX(for node: CanvasNode, direction: Double) -> Double {
        direction >= 0 ? node.bounds.x : node.bounds.x + node.bounds.width
    }

    private static func constrainBranchX(_ branchX: Double, startX: Double, endX: Double) -> Double {
        if endX >= startX {
            let lower = startX + minimumLegLength
            let upper = endX - minimumBranchGap
            guard lower <= upper else {
                return startX + ((endX - startX) / 2)
            }
            return min(max(branchX, lower), upper)
        }

        let lower = endX + minimumBranchGap
        let upper = startX - minimumLegLength
        guard lower <= upper else {
            return startX + ((endX - startX) / 2)
        }
        return min(max(branchX, lower), upper)
    }
}
