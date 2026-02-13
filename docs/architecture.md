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
| Directory | 責務 |
|---|---|
| `App` | `HotkeyCanvasApp` のエントリポイント、DependencyContainer の初期化 |
| `Domain` | ドメインの中核。状態と操作の不変条件を保持 |
| `Domain/Model` | `CanvasState`, `Node`, `Edge` などの純粋データ構造 |
| `Domain/Command` | ドメインで扱う編集操作コマンドの定義 |
| `Domain/Service` | 純粋関数の reducer、undo 情報の合成 |
| `Domain/Error` | ドメイン整合性違反などのエラー定義 |
| `Application` | ユースケース単位のオーケストレーション |
| `Application/UseCase` | `Apply/Undo/Redo/Save/Load/AgentEdit` の実行単位 |
| `Application/DTO` | UseCase 入出力データ (`ApplyResult`, `SideEffect`) |
| `Application/Port` | 外部依存に対する抽象境界 (protocol) |
| `Application/Port/Input` | UI/外部から受ける入力境界 |
| `Application/Port/Output` | 状態通知や画面更新の出力境界 |
| `Application/Port/Gateway` | 保存・AI・スナップショットなど外部I/O境界 |
| `Application/Coordinator` | 複数ユースケース横断の編集セッション制御 |
| `InterfaceAdapters` | 入出力・外部形式を Application/Domain へ接続 |
| `InterfaceAdapters/Input` | 外部入力の取り込み |
| `InterfaceAdapters/Input/Hotkey` | `NSEvent`/ショートカットを `CanvasCommand` へ変換 |
| `InterfaceAdapters/Output` | UI描画・表示更新の実装群 |
| `InterfaceAdapters/Output/ViewModel` | Application 出力を SwiftUI 用状態へ変換 |
| `InterfaceAdapters/Output/SwiftUI` | SwiftUI View コンポーネント |
| `InterfaceAdapters/Output/Metal` | Metal による描画実装 |
| `InterfaceAdapters/Persistence` | 永続化アダプタ |
| `InterfaceAdapters/Persistence/JsonCanvas` | Domain と Json Canvas のマッピング、ファイル保存 |
| `InterfaceAdapters/Agent` | Agent API 連携、Command 変換、編集状態スナップショット取得 |
| `Infrastructure` | 横断的な技術基盤 |
| `Infrastructure/Logging` | ログ出力の実装 |
| `Infrastructure/Diagnostics` | メトリクス・診断情報の収集 |
| `Tests` | テスト全体の入口 |
| `Tests/DomainTests` | Domain の純粋関数・不変条件テスト |
| `Tests/ApplicationTests` | UseCase/Port 契約テスト |
| `Tests/InterfaceAdapterTests` | 入出力変換、Mapper テスト |
| `Tests/IntegrationTests` | Hotkey -> Apply -> Render など統合シナリオ |
| `docs` | 設計・運用ドキュメント |

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
