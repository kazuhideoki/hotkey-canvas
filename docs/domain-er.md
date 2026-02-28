# HotkeyCanvas Domain ER図

## 1. 目的

- `Sources/Domain/` の主要モデル間の関係を、実装準拠で可視化する。
- `docs/domain.md` の読解補助として、集約境界と多重度を明示する。
- 各ドメインの責務・不変条件・利用状況の本文は `docs/domain.md` を正本として参照する。

## 2. スコープ

- 対象は Domain の主要エンティティ/値オブジェクトのうち、現時点で ER として可視化済みの領域（キャンバス編集コア、ショートカット解決）。
- サービス実装詳細（アルゴリズム）は対象外。

## 3. キャンバス編集コア ER

```mermaid
erDiagram
    CanvasGraph ||--o{ CanvasNode : "nodesByID"
    CanvasGraph ||--o{ CanvasEdge : "edgesByID"
    CanvasGraph ||--o{ CanvasArea : "areasByID"

    CanvasNode ||--o{ CanvasAttachment : "attachments"

    CanvasNode ||--o{ CanvasEdge : "fromNodeID"
    CanvasNode ||--o{ CanvasEdge : "toNodeID"

    CanvasArea ||--o{ CanvasNode : "nodeIDs"

    CanvasGraph {
        CanvasNodeID focusedNodeID "0..1"
        Set_CanvasNodeID selectedNodeIDs
        Set_CanvasNodeID collapsedRootNodeIDs
    }

    CanvasNode {
        CanvasNodeID id PK
        CanvasNodeKind kind
        string text "optional"
        CanvasBounds bounds
        bool markdownStyleEnabled
    }

    CanvasAttachment {
        CanvasAttachmentID id PK
        CanvasAttachmentKind kind
        CanvasAttachmentPlacement placement
    }

    CanvasEdge {
        CanvasEdgeID id PK
        CanvasNodeID fromNodeID FK
        CanvasNodeID toNodeID FK
        CanvasEdgeRelationType relationType
        int parentChildOrder "optional"
    }

    CanvasArea {
        CanvasAreaID id PK
        CanvasEditingMode editingMode
    }
```

補足:

- `CanvasArea` と `CanvasNode` は実装上 `nodeIDs: Set<CanvasNodeID>` による参照。  
  ドメイン不変条件として「各 `CanvasNode` はちょうど1つの `CanvasArea` に所属」する。
- `CanvasEdge` は `fromNodeID` と `toNodeID` で `CanvasNode` を参照する有向辺。
- `collapsedRootNodeIDs` は「可視性計算の入力集合」で、ノード実体は `CanvasNode` 側に存在する。

## 4. ショートカット解決 ER

```mermaid
erDiagram
    CanvasShortcutCatalogService ||--o{ CanvasShortcutDefinition : "provides"
    CanvasShortcutDefinition ||--|| CanvasShortcutID : "id"
    CanvasShortcutDefinition ||--|| CanvasShortcutGesture : "gesture"
    CanvasShortcutDefinition ||--|| CanvasShortcutAction : "action"
    CanvasShortcutDefinition ||--|| CanvasCommandPaletteLabel : "label"
    CanvasShortcutDefinition ||--|| CanvasCommandPaletteVisibility : "visibility"

    CanvasShortcutGesture ||--|| CanvasShortcutKey : "key"
    CanvasShortcutGesture ||--|| CanvasShortcutModifiers : "modifiers"

    KeymapIntentResolver ||--o{ KeymapResolvedRoute : "resolveRoute"
    KeymapResolvedRoute ||--|| KeymapShortcutScope : "scope"
    KeymapResolvedRoute ||--o| KeymapPrimitiveIntent : "primitive payload"
    KeymapResolvedRoute ||--o| KeymapGlobalAction : "global payload"
```

補足:

- `KeymapIntentResolver.resolveRoute(for:)` は現状 `primitive` / `global` を返し、非対応入力は `nil`。
- `modal` は `KeymapResolvedRoute` のスコープ語彙として存在するが、現実装では View 側状態管理で処理する。
