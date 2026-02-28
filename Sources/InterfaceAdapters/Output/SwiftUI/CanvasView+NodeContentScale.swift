// Background: Node-size scaling changes bounds independently from camera zoom.
// Responsibility: Provide one node content scale calculation shared by text and image rendering paths.
import Domain

extension CanvasView {
    func nodeContentScale(for node: CanvasNode) -> Double {
        let baselineWidth: Double =
            if isDiagramNode(node.id) {
                CanvasDefaultNodeDistance.diagramNodeSide
            } else {
                CanvasDefaultNodeDistance.treeNodeWidth
            }
        guard baselineWidth > 0 else {
            return 1
        }
        let scale = node.bounds.width / baselineWidth
        guard scale.isFinite, scale > 0 else {
            return 1
        }
        return scale
    }
}
