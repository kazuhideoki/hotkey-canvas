# HotkeyCanvas Architecture

## 1. 目的と設計方針

HotkeyCanvas は、キーボードファーストでキャンバスを編集できる macOS 向けアプリケーション。
初期フェーズでは Clean Architecture を採用し、実装詳細よりも責務境界を明確にする。

設計原則:

- Domain は純粋関数と不変データ中心
- Application はユースケースと状態遷移の調停
- InterfaceAdapters は入出力と外部形式変換
- Infrastructure は横断的な技術実装
- App は依存注入と起動配線のみ

## 2. レイヤー責務

| Layer             | 責務                                           | 禁止事項                             |
| ----------------- | ---------------------------------------------- | ------------------------------------ |
| App               | 起動、DI 組み立て、依存配線                    | ビジネスロジック実装                 |
| Domain            | モデル、不変条件、純粋な状態遷移               | UI/保存/外部API依存                  |
| Application       | ユースケース実行、`apply` 調停、Undo/Redo 制御 | UIフレームワーク依存、永続化詳細実装 |
| InterfaceAdapters | 入力変換、出力表示用変換、保存形式マッピング   | Domain/Application の責務侵食        |
| Infrastructure    | ログ、メトリクス等の技術基盤                   | ドメイン判断ロジック                 |

## 3. ディレクトリ責務マップ

```text
.
|-- App/                                  # エントリポイント、DI 組み立て、起動配線のみ
|   |-- HotkeyCanvasApp.swift             # ルート Scene 定義（命名: *App）
|   `-- DependencyContainer.swift         # 依存注入の集約点（命名: *Container）
|
|-- Domain/                               # ドメイン中核（純粋モデルと不変条件）
|   |-- Model/                            # CanvasState, Node, Edge などの純粋データ構造（型名: 名詞）
|   |-- Command/                          # ドメイン編集コマンド定義（型名: *Command）
|   |-- Service/                          # reducer など純粋関数、undo 情報の合成（型名: *Service）
|   `-- Error/                            # 整合性違反などのドメインエラー（型名: *Error）
|
|-- Application/                          # ユースケースのオーケストレーション
|   |-- UseCase/                          # 実行単位（表示文言・状態取得もここ経由、関数名は動詞開始）
|   |   `-- <Verb>UseCase.swift           # 命名: *UseCase
|   |-- DTO/                              # UseCase 入出力データ（型名: *Input/*Output/*Result）
|   |-- Port/                             # 外部依存への抽象境界（protocol）
|   |   |-- Input/                        # UI/外部 -> Application の入力境界
|   |   |                                 # 命名: *InputPort（例: GreetingInputPort）
|   |   |-- Output/                       # 状態通知や画面更新の出力境界（命名: *OutputPort）
|   |   `-- Gateway/                      # 保存・AI・外部I/O境界（命名: *Gateway）
|   `-- Coordinator/                      # 複数ユースケース横断制御（命名: *Coordinator）
|
|-- InterfaceAdapters/                    # 入出力・外部形式を Application/Domain へ接続
|   |-- Input/
|   |   `-- Hotkey/                       # NSEvent/ショートカット -> CanvasCommand 変換（命名: *Translator）
|   |-- Output/                           # UI描画・表示更新の実装群
|   |   |-- ViewModel/                    # Application 出力を表示状態へ変換
|   |   |                                 # ViewModel は Input Port の利用者であり、実装者ではない
|   |   |                                 # 命名: *ViewModel
|   |   |-- SwiftUI/                      # SwiftUI View コンポーネント（SwiftUI依存を閉じ込める）
|   |   |                                 # View は描画専念。文言・状態は直書きせず UseCase 経由で受け取る
|   |   |                                 # 命名: *View
|   |   `-- Metal/                        # Metal 描画実装（命名: *Renderer）
|   |-- Persistence/
|   |   `-- JsonCanvas/                   # Domain <-> Json Canvas 変換、ファイル保存（命名: *Mapper, *Repository）
|   `-- Agent/                            # Agent API 連携、Command 変換、状態スナップショット取得（命名: *Client）
|
|-- Infrastructure/                       # 横断的技術基盤
|   |-- Logging/                          # ログ出力実装（命名: *Logger）
|   `-- Diagnostics/                      # メトリクス・診断情報収集（命名: *Diagnostics, *Monitor）
|
|-- Tests/                                # テスト群（本体と同じ責務分割を反映）
|   |-- DomainTests/                      # Domain の純粋関数・不変条件テスト
|   |-- ApplicationTests/                 # UseCase/Port 契約テスト
|   |-- InterfaceAdapterTests/            # 入出力変換、Mapper テスト
|   `-- IntegrationTests/                 # Hotkey -> Apply -> Render 統合シナリオ
|                                         # ファイル命名: <TypeName>Tests.swift / 関数命名: test_<condition>_<expected>()
|
`-- docs/                                 # 設計・運用ドキュメント
```

## 4. 依存ルール

`## 3` の責務マップを前提に、依存方向のみ明文化する。

```text
App -> Application -> Domain
App -> InterfaceAdapters -> Application -> Domain
InterfaceAdapters -> Domain (型参照のみ許容)
Infrastructure -> (Application/InterfaceAdapters から利用)
```

禁止:

- `Domain` から `Application`/`InterfaceAdapters`/`Infrastructure` への依存
- `Application` から SwiftUI/Metal/JSON 実装詳細への依存

## 5. データ境界

- Domain は保存形式から独立したモデルを持つ。
- 保存形式との相互変換は `InterfaceAdapters/Persistence/*` に閉じ込める。
- 保存形式変更時は Mapper 差し替えで吸収する。

## 6. 操作境界 (`apply`)

`## 3` の `Application/Port/Input` で扱う編集中核契約。

```swift
protocol CanvasEditingInputPort {
    func apply(commands: [CanvasCommand]) async throws -> ApplyResult
}

struct ApplyResult {
    let newState: CanvasState
    let undoToken: UndoToken?
    let sideEffects: [SideEffect]
}
```

- `apply` はコマンド列の適用を一括で扱う。
- Undo/Redo に必要な情報は `ApplyResult` に副産物として含める。

## 7. Agent 連携境界

- Agent は UI を直接変更しない。
- Agent 連携は `Application/Port/Gateway/*Gateway` 経由で Command 列を生成し、`apply` で適用する。
- 編集状態の画像取得は Adapter 側の責務 (`InterfaceAdapters/Agent`) とする。

## 8. 最小シーケンス（サンプル）

```text
Hotkey Input
  -> InterfaceAdapters/Input/*Translator
  -> CanvasEditingInputPort.apply(commands)
  -> Application/UseCase/*UseCase
  -> Domain/Service reducer
  -> ApplyResult
  -> InterfaceAdapters/Output/*ViewModel update
  -> InterfaceAdapters/Output/SwiftUI|Metal render
```

## 9. 将来拡張方針

- マウス操作は Input Adapter を追加して同じ `apply` 契約に統合する。
- 重い処理の Rust オフロードは将来検討とし、初期は Swift 実装を優先する。
