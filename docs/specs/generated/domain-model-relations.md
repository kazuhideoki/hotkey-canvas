# HotkeyCanvas ドメインモデル関係図

この文書は `scripts/generate_domain_docs.sh` により自動生成されます。手動編集はしないでください。

- entity ノード数: 6
- entity 間参照数: 14

```mermaid
classDiagram
class CanvasArea {
  <<struct>>
  nodeIDs: Set<CanvasNodeID>
}
class CanvasAttachment {
  <<struct>>
}
class CanvasEdge {
  <<struct>>
  fromNodeID: CanvasNodeID
  toNodeID: CanvasNodeID
}
class CanvasGraph {
  <<struct>>
  nodesByID: [CanvasNodeID: CanvasNode]
  edgesByID: [CanvasEdgeID: CanvasEdge]
  focusedNodeID: CanvasNodeID?
  focusedElement: CanvasFocusedElement?
  selectedNodeIDs: Set<CanvasNodeID>
  selectedEdgeIDs: Set<CanvasEdgeID>
  collapsedRootNodeIDs: Set<CanvasNodeID>
  areasByID: [CanvasAreaID: CanvasArea]
}
class CanvasNode {
  <<struct>>
  attachments: [CanvasAttachment]
}
class CanvasShortcutDefinition {
  <<struct>>
}
CanvasArea "1" --> "*" CanvasNode : nodeIDs
CanvasEdge "1" --> "1" CanvasNode : fromNodeID
CanvasEdge "1" --> "1" CanvasNode : toNodeID
CanvasGraph "1" --> "*" CanvasArea : areasByID
CanvasGraph "1" --> "1" CanvasArea : focusedElement via CanvasFocusedElement
CanvasGraph "1" --> "*" CanvasEdge : edgesByID
CanvasGraph "1" --> "1" CanvasEdge : focusedElement via CanvasFocusedElement, CanvasEdgeFocus
CanvasGraph "1" --> "*" CanvasEdge : selectedEdgeIDs
CanvasGraph "1" --> "*" CanvasNode : collapsedRootNodeIDs
CanvasGraph "1" --> "1" CanvasNode : focusedElement via CanvasFocusedElement
CanvasGraph "1" --> "1" CanvasNode : focusedNodeID
CanvasGraph "1" --> "*" CanvasNode : nodesByID
CanvasGraph "1" --> "*" CanvasNode : selectedNodeIDs
CanvasNode "1" --> "*" CanvasAttachment : attachments
```
