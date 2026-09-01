# 拆掉 UseCase protocol 層：改用 TCA 風格的 Client

- 日期：2026-09-01
- 分支：`refactor`（基於 `837262f`）
- 前置：`docs/superpowers/specs/2026-08-31-rxswift-to-swift-concurrency-design.md`
  已完成（Rx / Combine / Swinject 移除、Swift 6 語言模式、CocoaPods → SPM）

## 1. 動機

目前的相依層是三個 protocol 各配一個實作：

| protocol | 實作 |
|---|---|
| `NetworkService` | `APIService`（actor） |
| `FavoriteUseCase` | `UserDefaultStore`（class + `OSAllocatedUnfairLock`） |
| `ListUsecase` | `ListUseCaseImp`（無狀態 struct） |

這三個 protocol **只**以 `any Protocol` 的形式出現在兩處：各 Store 的
`Dependency` struct，以及測試的 mock class。它們沒有第二個實作，也沒有多型
需求——存在的唯一理由是讓測試能替換。

改用 struct of closures（TCA 的 client 模式）之後，protocol 層可以真的消失，
而不是被推到另一層。

### 1.1 順帶結清的技術債

三個 mock 目前都掛 `@unchecked Sendable`。Task 1 的 review 把它列為 deferred
minor，理由是「『只在 MainActor 使用』的假設沒有任何東西強制」。

改成 Client 之後測試不再需要 mock class——直接組一個帶測試 closure 的值。
所有 closure 標 `@Sendable`，Sendable 由編譯器保證，那三個 `@unchecked`
一併消失。這是本次改動最實際的收益，比「少一層 protocol」重要。

## 2. 關鍵限制：stored closure 不能是泛型的

`NetworkService.request<T: Endpoint>(_ endpoint: T) async throws -> T.Model`
是泛型方法。**Swift 的 stored property 不能持有泛型 closure**，所以
`NetworkClient` 無法直接照搬這個簽名。

考慮過的兩條路：

**(a) 保留泛型入口，型別抹除**：`@Sendable (any Endpoint) async throws -> any Sendable`
再由呼叫端 `as?` 回來。能編譯，但把 `T.Model` 的編譯期關聯換成執行期轉型，
測試也得自己記得回傳對的型別。**否決**——這是退步。

**(b) Client 暴露領域操作，不暴露傳輸層**：採用此案。泛型問題消失，而且順手
修掉一個現有的漏抽象（見 §3.2）。

## 3. 設計

### 3.1 兩個 Client

```swift
struct PokemonAPIClient: Sendable {
    var list: @Sendable (_ offset: Int) async throws -> PokemonListResponse
    var pokemon: @Sendable (_ id: Int) async throws -> PokmonResponse
    var species: @Sendable (_ id: Int) async throws -> PokemonSpeciesResponse
}

struct FavoritesClient: Sendable {
    var contains: @Sendable (_ id: Int) -> Bool
    var add: @Sendable (_ id: Int) -> Void
    var remove: @Sendable (_ id: Int) -> Void
    var synchronize: @Sendable () -> Void
}
```

live 實作把現有的具體型別關進 client 內部：

```swift
extension PokemonAPIClient {
    static let live: PokemonAPIClient = {
        let service = APIService.share
        return .init(
            list: { try await service.request(PokemonListEndpont(offset: $0)) },
            pokemon: { try await service.request(PokemonEndpoint(id: "\($0)")) },
            species: { try await service.request(PokemonSpeciesEndpoint(id: "\($0)")) }
        )
    }()
}

extension FavoritesClient {
    static let live: FavoritesClient = {
        let store = UserDefaultStore.shared
        return .init(
            contains: { store.isContain("\($0)") },
            add: { store.insert("\($0)") },
            remove: { store.remove("\($0)") },
            synchronize: { store.synchronize() }
        )
    }()
}
```

### 3.2 邊界上順手清掉的兩個漏抽象

**id 用 `Int`，不用 `String`。** 字串化是儲存與 URL path 的細節。目前
`CellViewModel` 寫 `PokemonEndpoint(id: "\(number)")`、兩個 Store 寫
`favorite.isContain("\(id)")`——呼叫端不該知道這件事。轉換收進 live 實作。

**`Endpoint` 組裝退回 client。** 目前 `PokemonListStore.load()` 自己組
`PokemonListEndpont(offset:)`，傳輸層細節漏進了 Store。改成領域操作之後，
Store 只說「給我 offset 20 的清單」。

`Endpoint` protocol 與三個 endpoint 型別都保留，但只有 client 的 live 實作
看得到它們——這正是它們該待的位置。

### 3.3 刪除 `ListUsecase`

`listConvertCell([Item]) -> [CellViewModel]` 沒有 I/O、沒有外部資源，是一個純
`@MainActor` 工廠。它當初被抽成可注入介面的唯一理由是測試想塞假的
`CellViewModel`。

包成 Client 只是換名字——它不是 client。**直接刪除這個相依**，Store 自己 map：

```swift
viewState.cells += response.results.map { CellViewModel(source: $0) }
```

目前 4 個測試用 `MockListUseCase.injectCellViewModels`。改成餵
`Stub.listResponse` 走真實映射之後，測試驗證的是真實轉換行為，而不是
「mock 回傳了我塞進去的東西」——**覆蓋率是上升的**。

### 3.4 Store 不再包 `Dependency` struct

```swift
@Observable
@MainActor
final class PokemonListStore {

    private let api: PokemonAPIClient
    private let favorites: FavoritesClient
    private let coordinator: Coordinator

    init(
        coordinator: Coordinator,
        api: PokemonAPIClient = Dependencies.api,
        favorites: FavoritesClient = Dependencies.favorites
    ) {
        self.coordinator = coordinator
        self.api = api
        self.favorites = favorites
    }
}
```

嵌套的 `Dependency` struct 消失。**預設參數仍然是唯一的快照點，這條不能鬆。**

前一份 spec 的 §4.3 記錄了原因：`@TaskLocal` 的值在 `Task { }` 建立當下捕捉，
若改成在 `load()` 內直接讀 `Dependencies.api`，在 `withValue { }` 外建立的
Task 會讀到 live 實作而打到真實網路。快照成 `let` 才能讓測試穩定。

`CellViewModel` 比照改為持有 `PokemonAPIClient`。

`Dependencies` 由三個 TaskLocal 減為兩個：

```swift
enum Dependencies {
    @TaskLocal static var api: PokemonAPIClient = .live
    @TaskLocal static var favorites: FavoritesClient = .live
}
```

### 3.5 測試：三個 mock class 全部刪除

```swift
// 之前
let service = MockService()
service.injectAsyncResponse = try Stub.listResponse(numbers: [1, 2, 3], nextOffset: 20)
let list = MockListUseCase()
list.injectCellViewModels = [CellViewModel(source: try Stub.item(1)), ...]
let store = makeStore(service: service, list: list)

// 之後
let store = makeStore(api: .init(
    list: { _ in try Stub.listResponse(numbers: [1, 2, 3], nextOffset: 20) },
    pokemon: { Stub.pokemon(id: $0) },
    species: { _ in Stub.species() }
))
```

需要數呼叫次數的測試改用一個測試專用的 `Recorder`：

```swift
final class Recorder<Value>: Sendable {
    private let items = OSAllocatedUnfairLock<[Value]>(initialState: [])
    func record(_ value: Value) { items.withLock { $0.append(value) } }
    var recorded: [Value] { items.withLock { $0 } }
}
```

用 lock 而非 actor，是因為 `FavoritesClient` 的 closure 是同步的，actor 版
在同步 closure 裡無法 `await`，會逼出兩套寫法。

有兩個測試本質上就是在數呼叫次數，必須靠它：
`已經到底時loadMore不再發請求`、`species已存在時onAppear不發請求`。

### 3.6 移除未使用的成員

`FavoriteUseCase.isEmpty` / `UserDefaultStore.isEmpty` **零生產呼叫端**，
只有 `UserDefaultStoreTests` 的 4 個斷言在用它。一併移除。

那 4 個斷言改用 `isContain` 表達，覆蓋率不掉：「插入兩次不會變成兩筆」原本
就由檔尾 `XCTAssertEqual(injectUserDefault.stringArray(forKey: testKey), [value])`
守著。

`MockFavoriteUseCase.recordIsContain` 也是零斷言，隨 mock 檔案刪除一併消失。

## 4. 影響範圍

**新增（3）**

| 路徑 | 責任 |
|---|---|
| `Pokmon/Model/Client/PokemonAPIClient.swift` | 領域操作介面 + live 實作 |
| `Pokmon/Model/Client/FavoritesClient.swift` | 同上 |
| `PokmonTests/Recorder.swift` | 測試用的執行緒安全記錄器 |

**修改（10）**：`Dependencies.swift`、`PokemonListStore.swift`、
`PokemonDetailStore.swift`、`CellViewModel.swift`、`SceneDelegate.swift`、
`Pokmon/Feature/CoordinatorProcotocol.swift`、`PokemonListStoreTests.swift`、
`PokemonDetailStoreTests.swift`、`CellViewModelTests.swift`、
`UserDefaultStoreTests.swift`

`CoordinatorProcotocol.swift` 是 `PokemonDetailStore` 的唯一生產建構點，
`Dependency` struct 刪除後必須跟著改。

**刪除（4）**：`Pokmon/Model/UseCase/ListUseCase.swift`、
`PokmonTests/Mock/MockService.swift`、`PokmonTests/Mock/MockFavoriteUseCase.swift`、
`PokmonTests/Mock/MockListUSeCase.swift`

**保留但降級為 client 內部細節**：`NetworkService.swift`（刪掉 protocol，
留 `APIService` actor）、`FavoriteUseCase.swift`（刪掉 protocol，留
`UserDefaultStore`；檔名建議改為 `UserDefaultStore.swift`）、`Endpoint.swift`
與三個 endpoint 型別。

`MockCoordinator` 保留——`Coordinator` 是 UI 導航協定，不是資料相依，把它
改成 struct of closures 沒有好處（它的方法回傳值來自 view controller 生命週期）。

## 5. 已知取捨

**新增 API 要動 `PokemonAPIClient` 型別**，不像現在丟一個 `Endpoint` 進去就好。
本設計認為這是優點：它讓「這個 App 對後端有哪些依賴」成為一份看得見的清單。
但若團隊新增 endpoint 的頻率高，這會是摩擦點。

**`FavoritesClient` 的 closure 是同步的**，所以 `UserDefaultStore` 內部的
`OSAllocatedUnfairLock` 必須保留。換成 Client 不會讓併發安全變成免費的。

**`Recorder` 是測試專用的可變狀態容器**，本質上是把 mock class 的可變欄位
換了個位置。它的價值在於範圍更小（只記錄，不假裝實作介面）且明確地
`Sendable`，而不是消滅了可變狀態。

## 6. 驗證

- 26 個單元測試維持全綠。斷言語意不得改變——只換注入方式。
  （§3.3 的 4 個測試例外：它們的斷言會從「mock 回傳值」改為「真實映射結果」，
  這是刻意的覆蓋率提升，需在該步驟明確說明。）
- `xcodebuild build` / `xcodebuild test -project Pokmon.xcodeproj -scheme Pokmon`
  皆 SUCCEEDED
- app 端維持零警告
- 終局檢查：`git grep -n "any NetworkService\|any FavoriteUseCase\|any ListUsecase"`
  無命中
- 模擬器確認列表載入、切換版型、收藏、詳情頁與 species 回填行為不變

## 7. 不在範圍內

- `PokemonSpeciesResponse.color` 只在 decoder 中被寫入、從未被讀取。屬於
  response model 層，與本次重構無關，不動。
- `Coordinator` 的介面形式（見 §4 說明）。
- 前一份 spec 累積的其他 deferred minor（`CellViewModel.cancel()` 不重設
  `isLoading`、失去 per-field 去重等），留待該計畫的最終審查處理。
