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
| Layer | 責務 | 禁止事項 |
|---|---|---|
| App | 起動、DI 組み立て、依存配線 | ビジネスロジック実装 |
| Domain | モデル、不変条件、純粋な状態遷移 | UI/保存/外部API依存 |
| Application | ユースケース実行、`apply` 調停、Undo/Redo 制御 | UIフレームワーク依存、永続化詳細実装 |
| InterfaceAdapters | 入力変換、出力表示用変換、保存形式マッピング | Domain/Application の責務侵食 |
| Infrastructure | ログ、メトリクス等の技術基盤 | ドメイン判断ロジック |

## 3. ディレクトリ責務マップ
```text
.
|-- App/                                  # エントリポイント、DI 組み立て、起動配線のみ
|   |-- HotkeyCanvasApp                   # ルート Scene 定義
|   `-- DependencyContainer               # 依存注入の集約点
|
|-- Domain/                               # ドメイン中核（純粋モデルと不変条件）
|   |-- Model/                            # CanvasState, Node, Edge などの純粋データ構造
|   |-- Command/                          # ドメイン編集コマンド定義
|   |-- Service/                          # reducer など純粋関数、undo 情報の合成
|   `-- Error/                            # 整合性違反などのドメインエラー
|
|-- Application/                          # ユースケースのオーケストレーション
|   |-- UseCase/                          # Apply/Undo/Redo/Save/Load/AgentEdit 実行単位（表示文言・状態取得もここ経由）
|   |-- DTO/                              # UseCase 入出力データ (ApplyResult, SideEffect)
|   |-- Port/                             # 外部依存への抽象境界 (protocol)
|   |   |-- Input/                        # UI/外部 -> Application の入力境界
|   |   |                                 # 例: GreetingInputPort のような呼び出し契約
|   |   |-- Output/                       # 状態通知や画面更新の出力境界
|   |   `-- Gateway/                      # 保存・AI・スナップショット等の外部I/O境界
|   `-- Coordinator/                      # 複数ユースケース横断の編集セッション制御
|
|-- InterfaceAdapters/                    # 入出力・外部形式を Application/Domain へ接続
|   |-- Input/
|   |   `-- Hotkey/                       # NSEvent/ショートカット -> CanvasCommand 変換
|   |-- Output/                           # UI描画・表示更新の実装群
|   |   |-- ViewModel/                    # Application 出力を表示状態へ変換
|   |   |                                 # ViewModel は Input Port の利用者であり、実装者ではない
|   |   |-- SwiftUI/                      # SwiftUI View コンポーネント（SwiftUI依存を閉じ込める）
|   |   |                                 # View は描画専念。文言・状態は直書きせず UseCase 経由で受け取る
|   |   `-- Metal/                        # Metal 描画実装
|   |-- Persistence/
|   |   `-- JsonCanvas/                   # Domain <-> Json Canvas 変換、ファイル保存
|   `-- Agent/                            # Agent API 連携、Command 変換、状態スナップショット取得
|
|-- Infrastructure/                       # 横断的技術基盤
|   |-- Logging/                          # ログ出力実装
|   `-- Diagnostics/                      # メトリクス・診断情報収集
|
|-- Tests/                                # テスト群（本体と同じ責務分割を反映）
|   |-- DomainTests/                      # Domain の純粋関数・不変条件テスト
|   |-- ApplicationTests/                 # UseCase/Port 契約テスト
|   |-- InterfaceAdapterTests/            # 入出力変換、Mapper テスト
|   `-- IntegrationTests/                 # Hotkey -> Apply -> Render 統合シナリオ
|
`-- docs/                                 # 設計・運用ドキュメント
```

表示系の追加ルール:
- 画面表示に必要な文言・状態取得は、原則 View 直書きではなく UseCase 経由で取得する。

## 4. 依存ルール
依存方向は外側から内側へ。

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
- Domain は Json Canvas 形式に引きずられない独立モデルを持つ。
- Json Canvas との相互変換は `InterfaceAdapters/Persistence/JsonCanvas` の責務。
- 保存形式変更時は Mapper の差し替えで吸収する。

## 6. 操作境界 (`apply`)
Application の編集中核は以下を契約とする。

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
- Agent 連携は `Application/Port/Gateway/AgentGateway` 経由で Command 列を生成し、`apply` で適用する。
- 編集状態の画像取得は Adapter 側の責務 (`InterfaceAdapters/Agent`) とする。

## 8. 最小シーケンス（サンプル）
```text
Hotkey Input
  -> HotkeyTranslator
  -> CanvasEditingInputPort.apply(commands)
  -> UseCase
  -> Domain reducer
  -> ApplyResult
  -> ViewModel update
  -> SwiftUI/Metal render
```

## 9. 将来拡張方針
- マウス操作は Input Adapter を追加して同じ `apply` 契約に統合する。
- 重い処理の Rust オフロードは将来検討とし、初期は Swift 実装を優先する。
