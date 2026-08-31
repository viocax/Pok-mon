# RxSwift 全面退場：改用純 Swift Concurrency

- 日期：2026-08-31
- 分支：`concurrency`（基於 `73bf9d6`）
- 目的：技術改造 + 團隊講稿素材（UIKit 如何漸進搬遷至 Swift Concurrency）

## 1. 背景

`concurrency` 分支已完成第一階段：兩支 ViewModel 改寫為 `@MainActor` 的
Store，導航以 `withCheckedContinuation` 包成 `async`，`NetworkService` 補上
`async throws` 版本。但 Rx 尚未退場，且引入了 Combine 作為 UIKit 的綁定層。

本次的終點是**同時移除 RxSwift 與 Combine**，綁定層改用 Observation
（iOS 17+），並拔除 Swinject。專案的第三方相依從 7 個 pod 減為 2 個。

### 1.1 現況殘留

Rx 仍存在於 9 個檔案：

| 檔案 | 殘留內容 |
|---|---|
| `Model/NetworkService/NetworkService.swift` | 協定中的 `Observable` 版 `request` |
| `Feature/List/Cell/CellViewModel.swift` | `transform(Input) -> Output`、`Driver`、`flatMap` |
| `Feature/List/Cell/PokemonCell.swift` | `DisposeBag`、`drive` |
| `Feature/UIComponent/EmptyView.swift` | `Reactive.Binder` extension |
| `Feature/UIComponent/IndicatorView.swift` | `Reactive.Binder` extension |
| `Model/ErrorTracker.swift` | 整檔（已無呼叫端） |
| `Model/HUDTracker.swift` | 整檔（僅服務 Rx 版 `CellViewModel`） |
| `Feature/List/PokemonListViewController.swift` | `import RxCocoa`，只為 `view.rx.*` |
| `Feature/Detail/PokemonDeatilPageViewController.swift` | 同上 |

測試端另有 `MockService`、`MockFavoriteUseCase`、`CellViewModelTests` 依賴
RxSwift / RxTest。

### 1.2 現況缺口

`PokemonListViewModelTests` 與 `PokemonDeatilPageViewModelTests` 在改寫
Store 時被刪除且未補回。**兩個 Store 目前零測試覆蓋。**

## 2. 先期驗證

以下結論皆在隔離的 git worktree 中實測取得，非推論。

### 2.1 Swift 6 語言模式的錯誤面積

將 `SWIFT_VERSION` 由 5.0 改為 6.0（`project.pbxproj` 中 6 處，全部位於
app 與 test target，Pods 各自保留原設定），逐輪修正至編譯通過。App target
共 7 處錯誤：

1. `APIService.share` — non-Sendable 型別的靜態屬性
2. `UserDefaultWrapper.share` — 同上
3. `InjectObject.shared` — 同上
4. `NetworkService` — 協定需 `: Sendable`
5. `Endpoint.Model` — `continuation.resume(returning:)` 送出非 Sendable 值
6. `PokemonDetailInfoCellDelegate` — conformance 跨進 MainActor
7. `CellViewModel` — 不是 Sendable，卻作為 diffable data source 的
   item identifier

測試 target 另有 `MockService` 兩處，隨 Rx 移除一併處理。

**Alamofire、Kingfisher、Swinject 均不需要 `@preconcurrency import`。**
原因是 Pods 各 target 停在 Swift 5，跨模組匯入自動套用寬鬆診斷規則。這是
講稿第 9 章的核心論點：升級語言模式不必等第三方先升。

### 2.2 已驗證可行的寫法

以 `swiftc -swift-version 6 -target arm64-apple-ios17.2-simulator -typecheck`
驗證：

- `@Observable` + `@MainActor` + 手寫 `nonisolated` 的 `Hashable` 可共存
- `observe` helper 必須掛在 `UIResponder`（UIKit 已標 `@MainActor`）；
  掛在裸 `NSObject` 會因 `NSObject` 非 Sendable 而失敗
- `NSDiffableDataSourceSnapshot` 接受 `@MainActor` class 作為 identifier
  （`@MainActor` 型別隱含 Sendable）
- `isolated deinit` 可用（Xcode 26 / Swift 6.2）
- `actor APIService` 需要 `protocol Endpoint: Sendable` 才能滿足協定需求
- `OSAllocatedUnfairLock`（iOS 16+）可讓 `UserDefaultStore` 成為 Sendable
  而不必變成 actor

## 3. 目標架構

```
@Observable @MainActor Store  ──observe { }──▶  UIKit ViewController / Cell
        │
        ├─ Task / Task.isCancelled            （生命週期）
        ├─ @TaskLocal Dependencies            （相依注入）
        └─ actor APIService ─ async throws ──▶ Alamofire（關在 actor 內）
```

無 RxSwift、無 Combine、無 Swinject。

## 4. 設計決策

以下三項在設計階段提供了替代方案，此處記錄最終選擇與其後果。

### 4.1 `CellViewModel` 保留為 class，釘在 MainActor

**選擇**：不拆成「ID + 值型別」，維持 class，加 `@MainActor` 取得 Sendable。

**後果與對策**：`==` 與 `hash(into:)` 是 nonisolated 需求，只能比對
`nonisolated let number`。因此當 pokemon 資料載入完成時，diffable 的
snapshot 不變，cell 不會重刷 —— 現在之所以會刷，是靠 Rx 的 `drive` 直接
把值推進 label，Rx 一移除這條線就斷了。

對策：**`CellViewModel` 本身也標記 `@Observable`**，由 cell 以
`observe { }` 訂閱。可變狀態留在 class 內，diffable 身分穩定在 `number`
上，重刷機制從 Rx 換成 Observation。這是 1:1 的對照關係，適合作為講稿的
遷移範例。

**已知張力**：`CellViewModel` 仍身兼 item identifier、自行發網路請求的
view model、跨頁面資料包三職。本輪不動其職責，於講稿第 7 章記錄為
「下一步可以怎麼走」。

### 4.2 Store 保留單一 `viewState: State` struct

**選擇**：不將 `State` 展平為多個 stored property。

**後果與對策**：`withObservationTracking` 追蹤的是「屬性存取」。讀取
`store.viewState.isLoading` 註冊的是整個 `viewState` 屬性，因此**任何欄位
變動都會讓所有 `observe` closure 重跑**。

檢視各 closure 的冪等性：

| 動作 | 冪等？ | 處置 |
|---|---|---|
| `title = state.title` | 是 | 不處理 |
| `applyLayout(isList:)` | 是（已有 `newLayout != current` 判斷） | 不處理 |
| `dataSource.apply(snapshot)` | 是（diffable 內部比對，相同則無動作） | 不處理 |
| `setLoading` / `setEmpty` | 是（依 bool 加掛或移除 subview） | 不處理 |
| `presentAlert` | **否** | 加 `presentedAlert` 欄位擋重複 present |

若日後 cell 數量成長到 `dataSource.apply` 成為熱點，即為回頭展平屬性的訊號。

### 4.3 相依注入改用 `@TaskLocal`

**選擇**：不用建構子注入，改以 TaskLocal 覆寫（swift-dependencies 風格），
保留呼叫端的簡潔。

**後果與對策**：TaskLocal 的值在 `Task { }` 建立時捕捉。若 Store 沿用現有
`@Injected` 的「每次存取才 resolve」語義，測試會踩到「Task 建立時機決定讀到
誰」的坑 —— 在 `withValue { }` 外建立的 Task 會讀到 live 實作而打到真實網路。

對策：**`Dependency` 於 `init` 時將 TaskLocal 快照為 `let`，之後不再重讀。**
測試只需在 `withValue { }` 內建立 Store 即可穩定。此坑本身列入講稿第 8 章。

`Task.detached` 不繼承 TaskLocal，專案內不使用 `Task.detached`。

## 5. 實作範圍

### 5.1 相依瘦身

`Podfile` 移除 `RxSwift`、`RxCocoa`、`Swinject`（`Pokmon` target）與
`RxBlocking`、`RxTest`（`PokmonTests` target），保留 `Alamofire`、
`Kingfisher`。執行 `pod install` 重新產生 `Pods/` 與 `Podfile.lock`。

### 5.2 併發基線

`Pokmon.xcodeproj/project.pbxproj` 中 6 處 `SWIFT_VERSION = 5.0` 改為 `6.0`
（app、unit test、UI test 各自的 Debug/Release）。Pods 不動。

### 5.3 相依注入

新增 `Pokmon/Model/Dependencies.swift`：

```swift
enum Dependencies {
    @TaskLocal static var network: any NetworkService = APIService.shared
    @TaskLocal static var favorite: any FavoriteUseCase = UserDefaultStore.shared
    @TaskLocal static var list: any ListUsecase = ListUseCaseImp()
}
```

各 Store 的 `Dependency` 改為在 `init` 快照：

```swift
struct Dependency {
    let service: any NetworkService
    let favorite: any FavoriteUseCase
    let list: any ListUsecase
    let coordinator: Coordinator

    init(
        coordinator: Coordinator,
        service: any NetworkService = Dependencies.network,
        favorite: any FavoriteUseCase = Dependencies.favorite,
        list: any ListUsecase = Dependencies.list
    ) { ... }
}
```

刪除 `Pokmon/Model/InjectObject.swift`（含 `@Injected` property wrapper 與
`Resolver.resolveService`）與 `PokmonTests/Mock/InjectObjectTestable.swift`。

連帶的 Sendable 調整：

| 目標 | 改法 |
|---|---|
| `Endpoint` | `protocol Endpoint: Sendable`，`associatedtype Model: Codable & Sendable` |
| `NetworkService` | `protocol NetworkService: Sendable`，刪除 `Observable` 版 `request` |
| `APIService` | `final class` 改為 `actor`，Alamofire `Session` 關在 actor 內 |
| `FavoriteUseCase` | `protocol FavoriteUseCase: Sendable` |
| `UserDefaultWrapper` | 更名 `UserDefaultStore`，`Set<String>` 改由 `OSAllocatedUnfairLock` 保護；`UserDefaults` 欄位標 `nonisolated(unsafe)` 並註明其 thread-safe 依據 |
| `ListUsecase` | `protocol ListUsecase: Sendable`（`ListUseCaseImp` 為無狀態 struct，天然符合） |

### 5.4 綁定層

新增 `Pokmon/Extension/UIResponder++Observe.swift`：

```swift
@MainActor
extension UIResponder {
    func observe(_ apply: @escaping @MainActor () -> Void) {
        withObservationTracking(apply) {
            Task { @MainActor [weak self] in self?.observe(apply) }
        }
    }
}
```

兩個 Store 由 `@Published private(set) var viewState` 改為 `@Observable` +
`private(set) var viewState`。刪除 `PokemonDetailStore.isFavoritePublisher`。

`PokemonDetailStore.Info` 的 `isFavorite` 欄位由
`AnyPublisher<Bool, Never>` 改為 `@MainActor () -> Bool`。closure 於
`observe` 內讀取 store 屬性即完成追蹤註冊，cell 無需認識 Store 型別。

### 5.5 Rx 逐檔清除

| 檔案 | 動作 |
|---|---|
| `Model/ErrorTracker.swift` | 整檔刪除 |
| `Model/HUDTracker.swift` | 整檔刪除 |
| `Feature/List/Cell/CellViewModel.swift` | 刪 `Input`/`Output`/`transform`；改 `@Observable @MainActor final class`；自帶 `loadTask` 與 `load()`；`nonisolated let number` 與 nonisolated `Hashable` |
| `Feature/List/CellViewModel+Hashable.swift` | 併入 `CellViewModel.swift` 後刪除 |
| `Feature/List/Cell/PokemonCell.swift` | `DisposeBag` + `drive` 改為 `observe { }`；`prepareForReuse` 取消訂閱與 task |
| `Feature/UIComponent/EmptyView.swift` | `Reactive.Binder` 改為 `UIView.setEmpty(_:)` |
| `Feature/UIComponent/IndicatorView.swift` | `Reactive.Binder` 改為 `UIView.setLoading(_:)` |
| `Feature/List/PokemonListViewController.swift` | 刪 `import Combine` / `import RxCocoa`；`sink` 改 `observe`；加 `presentedAlert` 防重複 |
| `Feature/Detail/PokemonDeatilPageViewController.swift` | 同上；`deinit` 改 `isolated deinit` |
| `Feature/Detail/Cell/PokemonDetailInfoCell.swift` | 刪 `import Combine` 與 `cancellables`；`Info.isFavorite` 改用 closure；`PokemonDetailInfoCellDelegate` 加 `@MainActor` |

### 5.6 測試

| 檔案 | 動作 |
|---|---|
| `PokmonTests/Mock/InjectObjectTestable.swift` | 刪除 |
| `PokmonTests/Mock/MockService.swift` | 刪 Rx；改 `@MainActor final class`；保留可注入回應與錯誤 |
| `PokmonTests/Mock/MockFavoriteUseCase.swift` | 刪 `import RxSwift`；改 `@MainActor final class` |
| `PokmonTests/Mock/MockListUSeCase.swift` | 改 `@MainActor final class` |
| `PokmonTests/Mock/MockCoordinator.swift` | 保留，確認 Sendable 相容 |
| `PokmonTests/CellViewModelTests.swift` | 改 Swift Testing；`TestScheduler` 虛擬時間改為 `await viewModel.loadTask?.value` |
| `PokmonTests/UserDefaultWrapperTests.swift` | 更名 `UserDefaultStoreTests.swift`，改測 lock 版 |
| `PokmonTests/PokemonListStoreTests.swift` | **新增**（Swift Testing） |
| `PokmonTests/PokemonDetailStoreTests.swift` | **新增**（Swift Testing） |

新增測試須涵蓋的行為：

- `PokemonListStore`：載入成功後填入 cells 與 `nextOffset`；載入失敗設定
  `alert`；`loadMore` 在 `nextOffset == nil` 時不發請求；`tapFavorite`
  切換過濾且 `displayCells` 隨之改變；`tapChangeLayout` 切換版型；
  `dismissAlert` 清除 alert；重複 `load()` 時前一個 task 被取消且
  `isLoading` 不閃動
- `PokemonDetailStore`：`species` 已存在時 `onAppear` 不發請求；載入失敗
  設定 alert 且 `dismissAlert` 會重試；`tapFavorite` 切換收藏狀態；
  `viewWillDisappear` 觸發 `synchronize()`

測試以 `Dependencies.$network.withValue(mock) { }` 包住 Store 的建立。

## 6. 講稿

輸出至 `docs/uikit-to-concurrency/`，章節對應 commit：

| 章 | 主題 | 對應 |
|---|---|---|
| 1 | 為什麼要搬：Rx 的三個成本與本專案現況數字 | — |
| 2 | 先立地基：`async` 版 NetworkService 與 Rx 並存 | `8d44f10` |
| 3 | `transform(Input) -> Output` 換成 `send(Action)` + State | `d63c3d8` `c503004` |
| 4 | `DisposeBag` 換 `Task` handle，與 `Task.isCancelled` 的陷阱 | `e65bc0a` |
| 5 | 導航：delegate/closure 換 `withCheckedContinuation` | `d63c3d8`（協定改 `async`）`c503004`（接上 continuation） |
| 6 | 綁定層換血：Combine 換 Observation | 本次 |
| 7 | 最後一哩：cell 層的 `Driver`/`drive` 換 `observe` | 本次 |
| 8 | 拔掉 DI 容器：Swinject 換 `@TaskLocal` | 本次 |
| 9 | 打開 Swift 6：七個錯誤逐一解讀，以及第三方為何沒炸 | 本次 |
| 10 | 測試也一起搬：RxTest `TestScheduler` 換 Swift Testing | 本次 |
| 11 | 收尾：Podfile 7 → 2，與可以回答的問題 | 本次 |

第 1 至 5 章回顧分支上已完成的 commit；第 6 至 11 章為本次產出。每章包含
before / after 程式碼對照與「為什麼是這個順序」的說明。

## 7. 驗證

每個步驟皆須通過：

```
xcodebuild build -workspace Pokmon.xcworkspace -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -workspace Pokmon.xcworkspace -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

測試須跑完整 scheme，不得僅以 `-only-testing:` 的局部通過作為驗證。

終局檢查：

- `git grep -in "RxSwift\|RxCocoa\|RxRelay\|Swinject\|import Combine" -- Pokmon PokmonTests`
  無命中
- `Podfile.lock` 僅列 Alamofire 與 Kingfisher
- App 於模擬器啟動，列表載入、切換版型、收藏過濾、進入詳情頁、返回後
  species 回填等流程與遷移前一致

## 8. 不在範圍內

- `CellViewModel` 的職責拆分（見 4.1，僅於講稿記錄）
- `PokemonListViewController` 與 `PokemonDeatilPageViewController` 的版面
  或行為調整
- UI 測試（`PokmonUITests`）的內容擴充
- 第三方套件升版
