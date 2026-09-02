# UseCase protocol → Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把三個只為測試而存在的 UseCase protocol 換成兩個 TCA 風格的 Client（struct of closures），刪除 `ListUsecase` 相依，並讓 Store 不再包一層 `Dependency` struct。

**Architecture:** Client 是 `Sendable` 的 struct，欄位是 `@Sendable` closure，暴露領域操作而非傳輸層。`live` 實作把 `APIService` actor、`UserDefaultStore` 與 `Endpoint` 型別關進內部。Store 直接持有 client 為 `let`，由預設參數從 `Dependencies` 的 `@TaskLocal` 快照。

**Tech Stack:** Swift 6.2 / Xcode 26、UIKit、Observation、Swift Testing、SPM（Alamofire、Kingfisher）。

**Spec:** `docs/superpowers/specs/2026-09-01-usecase-to-client-design.md`

## Global Constraints

- 分支：`refactor`。每個 Task 結束時 commit。
- 部署目標 `IPHONEOS_DEPLOYMENT_TARGET = 17.2`，不得使用 iOS 18+ API（`OSAllocatedUnfairLock` 是 iOS 16+，可用；`Synchronization.Mutex` 不可用）。
- Swift 6 語言模式已開啟。**不得使用 `@unchecked Sendable`**——本次改動的目的之一就是清掉它。若某處看似需要，回報而非自行加上。
- 相依只允許 Alamofire 與 Kingfisher，禁止新增任何套件。
- 禁止使用 `Task.detached`（不繼承 `@TaskLocal`）。
- **`Dependencies` 的讀取只能發生在 init 的預設參數位置。** 禁止在方法內（尤其 `Task { }` 內）讀 `Dependencies.*`——那會踩回 spec §3.4 記錄的坑。
- 26 個單元測試必須維持全綠。**斷言語意不得改變**，唯一例外是 Task 3 明列的 4 個測試（它們的斷言從「mock 回傳值」改為「真實映射結果」，是刻意的覆蓋率提升）。
- app 端必須維持**零警告**（前一個計畫的 Task 8 達成的標準，不得退步）。
- 每個 Task 最後都要跑**完整** scheme 的建置與測試，不得只用 `-only-testing:` 的局部通過作為驗證。

建置與測試指令（後續以 BUILD / TEST 代稱）：

```bash
# BUILD
xcodebuild build -project Pokmon.xcodeproj -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# TEST
xcodebuild test -project Pokmon.xcodeproj -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**測試計數注意**：`-project` 模式下 Swift Testing 用原生的 ✔/✘ 格式輸出，不是 `Test case '...' passed`。正確的計數方式：

```bash
# Swift Testing（25 個）
grep -oE '✔ Test [^ ]+\(\) passed' <log> | sort -u | wc -l
# XCTest（1 個，UserDefaultStoreTests）
grep -oE "Test Case '-\[PokmonTests\.[A-Za-z]+ [a-z_]+\]' passed" <log> | sort -u | wc -l
```

並行測試的輸出會交錯截斷行首，用 `grep -c 'Test case'` 這種寬鬆比對會少算。

## File Structure

**新增（3）**

| 路徑 | 責任 |
|---|---|
| `Pokmon/Model/Client/PokemonAPIClient.swift` | 三個領域操作 + `live`（內含 `APIService` 與 `Endpoint` 組裝） |
| `Pokmon/Model/Client/FavoritesClient.swift` | 四個收藏操作 + `live`（內含 `UserDefaultStore` 與 id 字串化） |
| `PokmonTests/Recorder.swift` | 測試用的執行緒安全記錄器 |

**修改（10）**：`Dependencies.swift`、`PokemonListStore.swift`、`PokemonDetailStore.swift`、`CellViewModel.swift`、`SceneDelegate.swift`、**`CoordinatorProcotocol.swift`**、`PokemonListStoreTests.swift`、`PokemonDetailStoreTests.swift`、`CellViewModelTests.swift`、`UserDefaultStoreTests.swift`

**刪除（4）**：`Pokmon/Model/UseCase/ListUseCase.swift`、`PokmonTests/Mock/MockService.swift`、`PokmonTests/Mock/MockFavoriteUseCase.swift`、`PokmonTests/Mock/MockListUSeCase.swift`

**更名（1）**：`Pokmon/Model/UseCase/FavoriteUseCase.swift` → `Pokmon/Model/UseCase/UserDefaultStore.swift`

**新增檔案必須手動掛進 pbxproj**（`objectVersion = 56`）的四處：`PBXBuildFile` / `PBXFileReference` / `PBXGroup` / `PBXSourcesBuildPhase`。`Client` 是新群組。掛完後必須驗證檔案真的被編譯到——**`BUILD SUCCEEDED` 不能證明這件事**，沒掛進 target 的檔案會被靜默忽略。可行的驗證法：在新檔案注入一個故意的型別錯誤、跑建置確認它報錯、再移除。

---

### Task 1: 建立兩個 Client、Recorder，並在 Dependencies 中並存

這一步只**新增**，不改任何呼叫端。舊的三個 `Dependencies` 欄位保留，新的兩個並存，所以全程可編譯。

**Files:**
- Create: `Pokmon/Model/Client/PokemonAPIClient.swift`
- Create: `Pokmon/Model/Client/FavoritesClient.swift`
- Create: `PokmonTests/Recorder.swift`
- Modify: `Pokmon/Model/Dependencies.swift`

**Interfaces:**
- Produces: `struct PokemonAPIClient: Sendable`，欄位 `list: @Sendable (Int) async throws -> PokemonListResponse`、`pokemon: @Sendable (Int) async throws -> PokmonResponse`、`species: @Sendable (Int) async throws -> PokemonSpeciesResponse`；`static let live`
- Produces: `struct FavoritesClient: Sendable`，欄位 `contains: @Sendable (Int) -> Bool`、`add: @Sendable (Int) -> Void`、`remove: @Sendable (Int) -> Void`、`synchronize: @Sendable () -> Void`；`static let live`
- Produces: `Dependencies.api: PokemonAPIClient`、`Dependencies.favorites: FavoritesClient`（皆 `@TaskLocal`，預設 `.live`）
- Produces: `final class Recorder<Value: Sendable>: Sendable`，含 `record(_:)`、`recorded: [Value]`、`count: Int`

- [ ] **Step 1: 建立 `PokemonAPIClient`**

Create `Pokmon/Model/Client/PokemonAPIClient.swift`：

```swift
//
//  PokemonAPIClient.swift
//  Pokmon
//
//  Created by drake on 2026/9/1.
//

import Foundation

/// 暴露領域操作，不暴露傳輸層。
///
/// 刻意不做成「丟一個 `Endpoint` 進來」的泛型入口：stored property 不能持有
/// 泛型 closure，硬要做就得型別抹除加執行期轉型，把 `T.Model` 的編譯期關聯
/// 換成 `as?`。改成列舉領域操作之後泛型問題消失，`Endpoint` 的組裝也退回
/// `live` 內部——那才是它該待的位置。
struct PokemonAPIClient: Sendable {
    var list: @Sendable (_ offset: Int) async throws -> PokemonListResponse
    var pokemon: @Sendable (_ id: Int) async throws -> PokmonResponse
    var species: @Sendable (_ id: Int) async throws -> PokemonSpeciesResponse
}

extension PokemonAPIClient {

    /// id 的字串化是 URL path 的細節，收在這裡，呼叫端只認得 `Int`。
    static let live: PokemonAPIClient = {
        let service = APIService.share
        return .init(
            list: { try await service.request(PokemonListEndpont(offset: $0)) },
            pokemon: { try await service.request(PokemonEndpoint(id: "\($0)")) },
            species: { try await service.request(PokemonSpeciesEndpoint(id: "\($0)")) }
        )
    }()
}
```

- [ ] **Step 2: 建立 `FavoritesClient`**

Create `Pokmon/Model/Client/FavoritesClient.swift`：

```swift
//
//  FavoritesClient.swift
//  Pokmon
//
//  Created by drake on 2026/9/1.
//

import Foundation

/// 名字刻意不叫 `DBClient`——背後是 `UserDefaults`，不是資料庫。
///
/// closure 是同步的，所以 `UserDefaultStore` 內部的 `OSAllocatedUnfairLock`
/// 仍然必要。換成 Client 不會讓併發安全變成免費的。
struct FavoritesClient: Sendable {
    var contains: @Sendable (_ id: Int) -> Bool
    var add: @Sendable (_ id: Int) -> Void
    var remove: @Sendable (_ id: Int) -> Void
    var synchronize: @Sendable () -> Void
}

extension FavoritesClient {

    /// id 的字串化是 `UserDefaults` 鍵值的細節，收在這裡。
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

- [ ] **Step 3: 在 `Dependencies` 中並存新舊欄位**

改寫 `Pokmon/Model/Dependencies.swift` 全檔：

```swift
//
//  Dependencies.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import Foundation

/// 取代 Swinject 容器。
///
/// 讀取規則：**只能在 init 的預設參數位置讀，讀到就存成 `let`**。
/// `@TaskLocal` 的值是在 `Task` 建立當下捕捉的，若在方法內（尤其 `Task { }`
/// 內）才讀，就會變成「Task 建立時機決定讀到誰」——在 `withValue { }` 外
/// 建立的 `Task` 會讀到 live 實作而打到真實網路。
enum Dependencies {

    @TaskLocal static var api: PokemonAPIClient = .live
    @TaskLocal static var favorites: FavoritesClient = .live

    // MARK: - 以下三項正在被上面兩個 Client 取代，最後一步會移除

    @TaskLocal static var network: any NetworkService = APIService.share
    @TaskLocal static var favorite: any FavoriteUseCase = UserDefaultStore.shared
    @TaskLocal static var list: any ListUsecase = ListUseCaseImp()
}
```

- [ ] **Step 4: 建立測試用的 `Recorder`**

Create `PokmonTests/Recorder.swift`：

```swift
//
//  Recorder.swift
//  PokmonTests
//
//  Created by drake on 2026/9/1.
//

import os

/// 測試用的執行緒安全記錄器。
///
/// 用 lock 而不是 actor：`FavoritesClient` 的 closure 是同步的，actor 版在同步
/// closure 裡無法 `await`，會逼出兩套寫法。
///
/// 它本質上是把 mock class 的可變欄位換了個位置——價值在於範圍更小（只記錄，
/// 不假裝實作介面）且 `Sendable` 由編譯器保證，而不是消滅了可變狀態。
final class Recorder<Value: Sendable>: Sendable {

    private let storage = OSAllocatedUnfairLock<[Value]>(initialState: [])

    func record(_ value: Value) {
        storage.withLock { $0.append(value) }
    }

    var recorded: [Value] {
        storage.withLock { $0 }
    }

    var count: Int {
        storage.withLock { $0.count }
    }
}
```

- [ ] **Step 5: 把三個新檔案掛進 pbxproj**

`PokemonAPIClient.swift` 與 `FavoritesClient.swift` 掛進 `Pokmon` target，放在新建的 `Client` 群組（位於 `Model` 群組下）。`Recorder.swift` 掛進 `PokmonTests` target。

每個檔案都要在四處出現：`PBXBuildFile`、`PBXFileReference`、`PBXGroup`、`PBXSourcesBuildPhase`。完成後跑 `plutil -lint Pokmon.xcodeproj/project.pbxproj` 確認結構完好。

- [ ] **Step 6: 驗證三個新檔案真的被編譯**

對每個新檔案分別注入一個故意的型別錯誤（例如在檔尾加 `fileprivate let __probe: Int = "x"`），跑 BUILD 確認它報出該檔案的錯誤，然後移除探針。

**`BUILD SUCCEEDED` 不能證明檔案被編譯**——沒掛進 target 的檔案會被靜默忽略，後面的 Task 才會炸。

- [ ] **Step 7: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED，且 app 端零警告

Run: TEST
Expected: TEST SUCCEEDED，26 個單元測試全過（此時尚無測試使用新型別，數字不變）

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "add PokemonAPIClient and FavoritesClient alongside the protocols

只新增,不改呼叫端,所以新舊並存且全程可編譯。

Client 暴露領域操作而非傳輸層:stored property 不能持有泛型 closure,
所以 request<T: Endpoint> 沒辦法照搬。改成列舉領域操作之後泛型問題消失,
Endpoint 的組裝與 id 字串化也一併退回 live 內部——呼叫端只認得 Int。

FavoritesClient 不叫 DBClient,背後是 UserDefaults 不是資料庫。"
```

---

### Task 2: `CellViewModel` 改吃 `PokemonAPIClient`

**Files:**
- Modify: `Pokmon/Feature/List/Cell/CellViewModel.swift`
- Modify: `PokmonTests/CellViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1 的 `PokemonAPIClient`、`Dependencies.api`、`Recorder`
- Produces: `CellViewModel.init(source: PokemonListResponse.Item, api: PokemonAPIClient = Dependencies.api, sepies: PokemonSpeciesResponse? = nil, pokemon: PokmonResponse? = nil)`

- [ ] **Step 1: 換掉 `CellViewModel` 的相依**

在 `Pokmon/Feature/List/Cell/CellViewModel.swift` 中，把：

```swift
    private let source: PokemonListResponse.Item
    private let service: any NetworkService

    init(
        source: PokemonListResponse.Item,
        service: any NetworkService = Dependencies.network,
        sepies: PokemonSpeciesResponse? = nil,
        pokemon: PokmonResponse? = nil
    ) {
        self.number = source.number
        self.source = source
        self.service = service
        self.sepies = sepies
        self.pokemon = pokemon
    }
```

改為：

```swift
    private let source: PokemonListResponse.Item
    private let api: PokemonAPIClient

    init(
        source: PokemonListResponse.Item,
        api: PokemonAPIClient = Dependencies.api,
        sepies: PokemonSpeciesResponse? = nil,
        pokemon: PokmonResponse? = nil
    ) {
        self.number = source.number
        self.source = source
        self.api = api
        self.sepies = sepies
        self.pokemon = pokemon
    }
```

並把 `bindView()` 內的：

```swift
            let response = try? await self.service.request(PokemonEndpoint(id: "\(self.number)"))
```

改為：

```swift
            let response = try? await self.api.pokemon(self.number)
```

其餘一律不動。

- [ ] **Step 2: 改寫 `CellViewModelTests`**

改寫 `PokmonTests/CellViewModelTests.swift` 全檔：

```swift
//
//  CellViewModelTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Testing
@testable import Pokmon

@MainActor
@Suite struct CellViewModelTests {

    let expectNumber = 3
    let expectName = "testNamePokeMon"
    let expectThumbnail = "https://pokeapi.co/api/v2/pokemon.png"

    private func makePokemon() -> PokmonResponse {
        .init(
            id: expectNumber,
            name: expectName,
            height: 111,
            weight: 22,
            sprites: .init(thumbnail: expectThumbnail),
            species: .init(name: "TestName", url: "TestName"),
            types: [],
            stats: []
        )
    }

    /// 只有 `pokemon` 會被這個型別呼叫，另兩個給一個明確失敗的實作，
    /// 誤呼叫時測試會紅而不是靜默通過。
    private func makeAPI(
        pokemon: @escaping @Sendable (Int) async throws -> PokmonResponse
    ) -> PokemonAPIClient {
        .init(
            list: { _ in throw PkError.badRequest },
            pokemon: pokemon,
            species: { _ in throw PkError.badRequest }
        )
    }

    @Test func 載入前後的輸出() async throws {
        let response = makePokemon()
        let viewModel = CellViewModel(
            source: try Stub.item(expectNumber),
            api: makeAPI(pokemon: { _ in response })
        )

        #expect(viewModel.numberText == "No.\(expectNumber)")
        #expect(viewModel.displayName == "")
        #expect(viewModel.imageURL == nil)

        viewModel.bindView()
        await viewModel.loadTask?.value

        #expect(viewModel.displayName == expectName)
        #expect(viewModel.imageURL == expectThumbnail)
        #expect(viewModel.types.isEmpty)
        #expect(viewModel.isLoading == false)
    }

    @Test func 已有pokemon時不重複請求() async throws {
        let calls = Recorder<Int>()
        let response = makePokemon()
        let viewModel = CellViewModel(
            source: try Stub.item(expectNumber),
            api: makeAPI(pokemon: { id in calls.record(id); return response }),
            pokemon: response
        )

        viewModel.bindView()
        await viewModel.loadTask?.value

        #expect(calls.recorded.isEmpty)
        #expect(viewModel.displayName == expectName)
    }

    @Test func pokemon尚未載入時getPokemon拋錯() throws {
        let viewModel = CellViewModel(
            source: try Stub.item(expectNumber),
            api: makeAPI(pokemon: { _ in throw PkError.badRequest })
        )

        #expect(throws: PkError.self) {
            try viewModel.getPokemon()
        }
        #expect(viewModel.spiecs == nil)
        #expect(viewModel.number == expectNumber)
    }

    @Test func pokemon已載入時getPokemon回傳() throws {
        let pokemon = makePokemon()
        let viewModel = CellViewModel(
            source: try Stub.item(expectNumber),
            api: makeAPI(pokemon: { _ in pokemon }),
            pokemon: pokemon
        )

        #expect(try viewModel.getPokemon().id == pokemon.id)
    }

    @Test func updateDetailPage寫入species() throws {
        let viewModel = CellViewModel(
            source: try Stub.item(expectNumber),
            api: makeAPI(pokemon: { _ in throw PkError.badRequest })
        )
        #expect(viewModel.spiecs == nil)

        viewModel.updateDetailPage(response: Stub.species())

        #expect(viewModel.spiecs != nil)
    }
}
```

**每個測試都明確傳入 `api`**，不靠預設值。預設值會讀到 `Dependencies.api` 也就是 live 實作，那會打真實網路。

- [ ] **Step 3: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED，app 端零警告

Run: TEST
Expected: TEST SUCCEEDED，26 個單元測試全過（`CellViewModelTests` 5 個）

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "move CellViewModel to PokemonAPIClient

bindView 內 service.request(PokemonEndpoint(id: \"\\(number)\")) 換成
api.pokemon(number) —— Endpoint 組裝與 id 字串化都退回 client 內部。

測試不再需要 MockService,改組一個帶測試 closure 的 client 值。每個測試都
明確傳入 api,不靠預設值:預設值會讀到 Dependencies.api 也就是 live 實作。
用不到的兩個 closure 給明確拋錯的實作,誤呼叫時測試會紅而不是靜默通過。"
```

---

### Task 3: `PokemonListStore` 拆掉 `Dependency` struct

**Files:**
- Modify: `Pokmon/Feature/List/PokemonListStore.swift`
- Modify: `Pokmon/SceneDelegate.swift`
- Modify: `PokmonTests/PokemonListStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 的 `PokemonAPIClient`、`FavoritesClient`、`Dependencies.api`、`Dependencies.favorites`、`Recorder`；Task 2 的 `CellViewModel.init(source:api:sepies:pokemon:)`
- Produces: `PokemonListStore.init(coordinator: Coordinator, api: PokemonAPIClient = Dependencies.api, favorites: FavoritesClient = Dependencies.favorites)`
- Produces: `PokemonListStore.Dependency` 不再存在

- [ ] **Step 1: 換掉 Store 的相依與 `Dependency` struct**

在 `Pokmon/Feature/List/PokemonListStore.swift`，把屬性與 init 從：

```swift
    private let dependency: Dependency

    /// `private(set)` 是為了讓測試能 await 到非同步流程結束
    private(set) var loadTask: Task<Void, Never>?
    private(set) var detailTask: Task<Void, Never>?

    // MARK: - Life cycle

    init(dependency: Dependency) {
        self.dependency = dependency
    }
```

改為：

```swift
    private let api: PokemonAPIClient
    private let favorites: FavoritesClient
    private let coordinator: Coordinator

    /// `private(set)` 是為了讓測試能 await 到非同步流程結束
    private(set) var loadTask: Task<Void, Never>?
    private(set) var detailTask: Task<Void, Never>?

    // MARK: - Life cycle

    /// `api` 與 `favorites` 的預設參數是唯一的快照點——`@TaskLocal` 只能在這裡讀。
    init(
        coordinator: Coordinator,
        api: PokemonAPIClient = Dependencies.api,
        favorites: FavoritesClient = Dependencies.favorites
    ) {
        self.coordinator = coordinator
        self.api = api
        self.favorites = favorites
    }
```

- [ ] **Step 2: 換掉 `load()` 的請求與映射**

把 `load()` 內的：

```swift
            do {
                let response: PokemonListResponse = try await self.dependency.service
                    .request(PokemonListEndpont(offset: offset))
                guard !Task.isCancelled else { return }

                self.viewState.nextOffset = response.offset
                self.viewState.cells += self.dependency.list.listConvertCell(response.results)
                self.syncFavorites()
```

改為：

```swift
            do {
                let response = try await self.api.list(offset)
                guard !Task.isCancelled else { return }

                self.viewState.nextOffset = response.offset
                // api 必須顯式傳下去。若靠 CellViewModel 的預設值，這裡會讀到
                // Dependencies.api 也就是 live 實作 —— 測試就會打真實網路。
                self.viewState.cells += response.results.map {
                    CellViewModel(source: $0, api: self.api)
                }
                self.syncFavorites()
```

- [ ] **Step 3: 換掉 `showDetail` 與 `syncFavorites`**

`showDetail` 內：

```swift
            let species = await self.dependency.coordinator.showDetailPage(model: cell)
```

改為：

```swift
            let species = await self.coordinator.showDetailPage(model: cell)
```

`syncFavorites` 整個改為（id 不再字串化）：

```swift
    private func syncFavorites() {
        viewState.favoriteNumbers = Set(
            viewState.cells
                .map(\.number)
                .filter { favorites.contains($0) }
        )
    }
```

- [ ] **Step 4: 刪除 `Dependency` struct**

刪除 `extension PokemonListStore` 末端整個 `struct Dependency { ... }` 區塊（含其 `init`）。`typealias Coordinator`、`State`、`Action` 都保留。

- [ ] **Step 5: 更新 `SceneDelegate`**

`Pokmon/SceneDelegate.swift` 中：

```swift
        let store = PokemonListStore(dependency: .init(coordinator: coordinator))
```

改為：

```swift
        let store = PokemonListStore(coordinator: coordinator)
```

並把 `sceneWillResignActive` 內的：

```swift
        Dependencies.favorite.synchronize()
```

改為：

```swift
        Dependencies.favorites.synchronize()
```

- [ ] **Step 6: 改寫 `PokemonListStoreTests`**

改寫 `PokmonTests/PokemonListStoreTests.swift` 全檔：

```swift
//
//  PokemonListStoreTests.swift
//  PokmonTests
//
//  Created by drake on 2026/8/31.
//

import Testing
@testable import Pokmon

@MainActor
@Suite struct PokemonListStoreTests {

    /// 未指定的 closure 給明確拋錯的實作，誤呼叫時測試會紅而不是靜默通過。
    private func makeAPI(
        list: @escaping @Sendable (Int) async throws -> PokemonListResponse = { _ in
            throw PkError.badRequest
        }
    ) -> PokemonAPIClient {
        .init(
            list: list,
            pokemon: { _ in throw PkError.badRequest },
            species: { _ in throw PkError.badRequest }
        )
    }

    /// `contains` 讀一個可變的旗標，讓測試中途能翻轉收藏狀態。
    private func makeFavorites(
        contains: @escaping @Sendable (Int) -> Bool = { _ in false }
    ) -> FavoritesClient {
        .init(
            contains: contains,
            add: { _ in },
            remove: { _ in },
            synchronize: { }
        )
    }

    private func makeStore(
        api: PokemonAPIClient? = nil,
        favorites: FavoritesClient? = nil,
        coordinator: MockCoordinator = .init()
    ) -> PokemonListStore {
        PokemonListStore(
            coordinator: coordinator,
            api: api ?? makeAPI(),
            favorites: favorites ?? makeFavorites()
        )
    }

    @Test func 載入成功時填入cells與nextOffset() async throws {
        let store = makeStore(
            api: makeAPI(list: { _ in try Stub.listResponse(numbers: [1, 2, 3], nextOffset: 20) })
        )
        store.send(.onAppear)
        await store.loadTask?.value

        // 走真實映射，所以可以直接斷言編號 —— 比原本只數 count 更強
        #expect(store.viewState.cells.map(\.number) == [1, 2, 3])
        #expect(store.viewState.nextOffset == 20)
        #expect(store.viewState.isLoading == false)
        #expect(store.viewState.alert == nil)
    }

    @Test func 載入失敗時設定alert() async throws {
        let store = makeStore(api: makeAPI(list: { _ in throw PkError.badRequest }))
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(store.viewState.alert != nil)
        #expect(store.viewState.cells.isEmpty)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 已經到底時loadMore不再發請求() async throws {
        let calls = Recorder<Int>()
        let store = makeStore(
            api: makeAPI(list: { offset in
                calls.record(offset)
                return try Stub.listResponse(numbers: [1], nextOffset: nil)
            })
        )
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.nextOffset == nil)
        #expect(store.viewState.hasNextPage == false)
        #expect(calls.count == 1)

        store.send(.loadMore)
        await store.loadTask?.value

        #expect(calls.count == 1)
    }

    @Test func 收藏過濾會改變displayCells() async throws {
        let isFavorite = Recorder<Bool>()
        // 用 Recorder 當可變旗標:record 一個值代表「之後都回傳這個」
        isFavorite.record(false)
        let store = makeStore(
            api: makeAPI(list: { _ in try Stub.listResponse(numbers: [1, 2], nextOffset: 20) }),
            favorites: makeFavorites(contains: { _ in isFavorite.recorded.last ?? false })
        )
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.displayCells.map(\.number) == [1, 2])

        isFavorite.record(true)
        store.send(.tapFavorite)

        #expect(store.viewState.isFavoriteFilterOn == true)
        #expect(store.viewState.displayCells.map(\.number) == [1, 2])

        isFavorite.record(false)
        store.send(.tapFavorite)
        store.send(.tapFavorite)

        #expect(store.viewState.isFavoriteFilterOn == true)
        #expect(store.viewState.displayCells.isEmpty)
        #expect(store.viewState.isEmpty == true)
    }

    @Test func 切換版型() {
        let store = makeStore()
        #expect(store.viewState.isListLayout == true)
        store.send(.tapChangeLayout)
        #expect(store.viewState.isListLayout == false)
    }

    @Test func dismissAlert清除alert() async throws {
        let store = makeStore(api: makeAPI(list: { _ in throw PkError.badRequest }))
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        store.send(.dismissAlert)
        #expect(store.viewState.alert == nil)
    }

    @Test func 點選cell後把species回填() async throws {
        let coordinator = MockCoordinator()
        coordinator.injectShowDetailPageAsync = Stub.species(cnName: "皮卡丘")
        let cell = CellViewModel(
            source: try Stub.item(25),
            api: makeAPI()
        )
        #expect(cell.spiecs == nil)

        let store = makeStore(coordinator: coordinator)
        store.send(.tapCell(cell))
        await store.detailTask?.value

        #expect(cell.spiecs?.names.first?.name == "皮卡丘")
    }
}
```

**四個測試的斷言刻意加強了**（`載入成功時填入cells與nextOffset`、`已經到底時loadMore不再發請求`、`收藏過濾會改變displayCells`、`點選cell後把species回填`）：原本靠 `MockListUseCase.injectCellViewModels` 塞入固定的 view model，斷言只能數 `count`；現在走真實映射，可以直接比對編號。這是 spec §3.3 明列的刻意提升，不是斷言漂移。

- [ ] **Step 7: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED，app 端零警告

Run: TEST
Expected: TEST SUCCEEDED，26 個單元測試全過（`PokemonListStoreTests` 7 個）

- [ ] **Step 8: 在模擬器上確認列表頁**

```bash
xcodebuild build -project Pokmon.xcodeproj -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DD
xcrun simctl boot "iPhone 17" || true
xcrun simctl install booted ./DD/Build/Products/Debug-iphonesimulator/Pokmon.app
xcrun simctl launch booted com.drake.Pokmon
sleep 12
xcrun simctl io booted screenshot /tmp/list-verify.png
```

Expected: 列表每格顯示編號、名稱、縮圖、屬性標籤與漸層邊框色。**若停在 Loading，代表 Step 2 的 `api` 沒有正確傳進 `CellViewModel`。**

不要嘗試用主機座標點擊 Simulator 視窗——這台機器沒有合成點擊工具，那條路會截到使用者的私人畫面。截圖確認初始列表即可，做不到就明講。

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "drop PokemonListStore's Dependency struct in favour of clients

Store 直接持有 api / favorites / coordinator 三個 let,嵌套的 Dependency struct
消失。預設參數仍是唯一的快照點 —— @TaskLocal 只能在那裡讀。

ListUsecase 相依直接刪掉而不是換成 client:它沒有 I/O,是純 @MainActor 工廠。
Store 自己 map,測試因此走真實映射。四個測試的斷言從只數 count 變成直接比對
編號,覆蓋率上升。

load() 內把 api 顯式傳進 CellViewModel。靠預設值會讀到 Dependencies.api
也就是 live 實作,測試就會打真實網路 —— 這是這一步最容易踩的坑。"
```

---

### Task 4: `PokemonDetailStore` 拆掉 `Dependency` struct

**Files:**
- Modify: `Pokmon/Feature/Detail/PokemonDetailStore.swift`
- Modify: `Pokmon/Feature/CoordinatorProcotocol.swift`
- Modify: `PokmonTests/PokemonDetailStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 的 `PokemonAPIClient`、`FavoritesClient`、`Dependencies.api`、`Dependencies.favorites`、`Recorder`
- Produces: `PokemonDetailStore.init(pokemon: PokmonResponse, species: PokemonSpeciesResponse?, api: PokemonAPIClient = Dependencies.api, favorites: FavoritesClient = Dependencies.favorites)`
- Produces: `PokemonDetailStore.pokemon` 由計算屬性改為 stored `let`
- Produces: `PokemonDetailStore.Dependency` 不再存在

- [ ] **Step 1: 換掉屬性與 init**

在 `Pokmon/Feature/Detail/PokemonDetailStore.swift`，把：

```swift
    private(set) var viewState: State = .init()

    private let dependency: Dependency

    /// `private(set)` 是為了讓測試能 await 到非同步流程結束
    private(set) var loadTask: Task<Void, Never>?

    // MARK: - Life cycle

    init(dependency: Dependency) {
        self.dependency = dependency

        viewState.title = "No.\(dependency.number)"
        viewState.isFavorite = dependency.favorite.isContain("\(dependency.number)")
        viewState.species = dependency.spiecs
    }
```

改為：

```swift
    private(set) var viewState: State = .init()

    let pokemon: PokmonResponse

    private let api: PokemonAPIClient
    private let favorites: FavoritesClient

    /// `private(set)` 是為了讓測試能 await 到非同步流程結束
    private(set) var loadTask: Task<Void, Never>?

    // MARK: - Life cycle

    /// `api` 與 `favorites` 的預設參數是唯一的快照點——`@TaskLocal` 只能在這裡讀。
    init(
        pokemon: PokmonResponse,
        species: PokemonSpeciesResponse?,
        api: PokemonAPIClient = Dependencies.api,
        favorites: FavoritesClient = Dependencies.favorites
    ) {
        self.pokemon = pokemon
        self.api = api
        self.favorites = favorites

        viewState.title = "No.\(pokemon.id)"
        viewState.isFavorite = favorites.contains(pokemon.id)
        viewState.species = species
    }
```

- [ ] **Step 2: 換掉 `send`、`load` 與 `toggleFavorite`**

`send` 內：

```swift
        case .viewWillDisappear:
            dependency.favorite.synchronize()
```

改為：

```swift
        case .viewWillDisappear:
            favorites.synchronize()
```

`load()` 內：

```swift
                let species: PokemonSpeciesResponse = try await self.dependency.service
                    .request(PokemonSpeciesEndpoint(id: "\(self.dependency.number)"))
```

改為：

```swift
                let species = try await self.api.species(self.pokemon.id)
```

`toggleFavorite` 整個改為（不再字串化 id）：

```swift
    private func toggleFavorite(_ id: Int) {
        // 依儲存決定方向,不依 viewState.isFavorite 這個畫面快取 ——
        // 兩者不同步時前者才是對的。PokemonDetailStoreTests 有測試釘住這點。
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.add(id)
        }
        viewState.isFavorite = favorites.contains(id)
    }
```

- [ ] **Step 3: 刪除 `Dependency` struct 與舊的 `pokemon` 計算屬性**

刪除 `extension PokemonDetailStore` 末端的整個 `struct Dependency { ... }` 區塊，以及最後一行：

```swift
    var pokemon: PokmonResponse { dependency.pokemon }
```

（`pokemon` 已在 Step 1 改為 stored `let`。）`State`、`Row`、`Action`、`Info` 都保留。

- [ ] **Step 4: 更新 `Coordinator`**

`Pokmon/Feature/CoordinatorProcotocol.swift` 中：

```swift
        let store = PokemonDetailStore(dependency: .init(spiecs: model.spiecs, pokemon: pokemon))
```

改為：

```swift
        let store = PokemonDetailStore(pokemon: pokemon, species: model.spiecs)
```

- [ ] **Step 5: 改寫 `PokemonDetailStoreTests`**

改寫 `PokmonTests/PokemonDetailStoreTests.swift` 全檔：

```swift
//
//  PokemonDetailStoreTests.swift
//  PokmonTests
//
//  Created by drake on 2026/8/31.
//

import Testing
@testable import Pokmon

@MainActor
@Suite struct PokemonDetailStoreTests {

    /// 未指定的 closure 給明確拋錯的實作，誤呼叫時測試會紅而不是靜默通過。
    private func makeAPI(
        species: @escaping @Sendable (Int) async throws -> PokemonSpeciesResponse = { _ in
            throw PkError.badRequest
        }
    ) -> PokemonAPIClient {
        .init(
            list: { _ in throw PkError.badRequest },
            pokemon: { _ in throw PkError.badRequest },
            species: species
        )
    }

    private func makeStore(
        species: PokemonSpeciesResponse? = nil,
        api: PokemonAPIClient? = nil,
        favorites: FavoritesClient? = nil
    ) -> PokemonDetailStore {
        PokemonDetailStore(
            pokemon: Stub.pokemon(id: 1),
            species: species,
            api: api ?? makeAPI(),
            favorites: favorites ?? .init(
                contains: { _ in false },
                add: { _ in },
                remove: { _ in },
                synchronize: { }
            )
        )
    }

    @Test func 初始化時帶入標題與收藏狀態() {
        let store = makeStore(favorites: .init(
            contains: { _ in true },
            add: { _ in },
            remove: { _ in },
            synchronize: { }
        ))

        #expect(store.viewState.title == "No.1")
        #expect(store.viewState.isFavorite == true)
    }

    @Test func species已存在時onAppear不發請求() async {
        let calls = Recorder<Int>()
        let store = makeStore(
            species: Stub.species(),
            api: makeAPI(species: { id in calls.record(id); return Stub.species() })
        )

        store.send(.onAppear)
        await store.loadTask?.value

        #expect(calls.recorded.isEmpty)
        #expect(store.viewState.isEmpty == false)
    }

    @Test func species不存在時onAppear發請求並填入() async {
        let calls = Recorder<Int>()
        let store = makeStore(
            api: makeAPI(species: { id in calls.record(id); return Stub.species() })
        )
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(calls.recorded == [1])
        #expect(store.viewState.species != nil)
        #expect(store.viewState.rows.count == 2)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 載入失敗時設定alert且dismiss會重試() async {
        let shouldFail = Recorder<Bool>()
        shouldFail.record(true)
        let store = makeStore(api: makeAPI(species: { _ in
            if shouldFail.recorded.last == true { throw PkError.badRequest }
            return Stub.species()
        }))

        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        shouldFail.record(false)
        store.send(.dismissAlert)
        await store.loadTask?.value

        #expect(store.viewState.alert == nil)
        #expect(store.viewState.species != nil)
    }

    @Test func 未收藏時點擊會新增() {
        let added = Recorder<Int>()
        let removed = Recorder<Int>()
        let store = makeStore(favorites: .init(
            contains: { _ in false },
            add: { added.record($0) },
            remove: { removed.record($0) },
            synchronize: { }
        ))
        #expect(store.viewState.isFavorite == false)

        store.send(.tapFavorite(1))

        #expect(added.recorded == [1])
        #expect(removed.recorded.isEmpty)
    }

    @Test func 已收藏時點擊會移除() {
        let added = Recorder<Int>()
        let removed = Recorder<Int>()
        let store = makeStore(favorites: .init(
            contains: { _ in true },
            add: { added.record($0) },
            remove: { removed.record($0) },
            synchronize: { }
        ))
        #expect(store.viewState.isFavorite == true)

        store.send(.tapFavorite(1))

        #expect(removed.recorded == [1])
        #expect(added.recorded.isEmpty)
    }

    /// 釘住「依儲存決定方向，而不是依畫面上的快取狀態」。
    /// 少了這個情境，把 toggleFavorite 改成看 viewState.isFavorite 也不會被抓到。
    @Test func 儲存與畫面狀態分歧時依儲存決定方向() {
        let contains = Recorder<Bool>()
        contains.record(false)
        let added = Recorder<Int>()
        let removed = Recorder<Int>()
        let store = makeStore(favorites: .init(
            contains: { _ in contains.recorded.last ?? false },
            add: { added.record($0) },
            remove: { removed.record($0) },
            synchronize: { }
        ))
        #expect(store.viewState.isFavorite == false)

        // 製造分歧：畫面說未收藏，儲存說已收藏
        contains.record(true)
        store.send(.tapFavorite(1))

        #expect(removed.recorded == [1])
        #expect(added.recorded.isEmpty)
    }

    @Test func viewWillDisappear觸發synchronize() {
        let synced = Recorder<Bool>()
        let store = makeStore(favorites: .init(
            contains: { _ in false },
            add: { _ in },
            remove: { _ in },
            synchronize: { synced.record(true) }
        ))

        store.send(.viewWillDisappear)

        #expect(synced.count == 1)
    }
}
```

斷言語意與改動前一致（`recordInsert == 1` 換成 `added.recorded == [1]`，多了參數本身的驗證）。

- [ ] **Step 6: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED，app 端零警告

Run: TEST
Expected: TEST SUCCEEDED，26 個單元測試全過（`PokemonDetailStoreTests` 8 個）

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "drop PokemonDetailStore's Dependency struct in favour of clients

pokemon 從計算屬性改為 stored let,species 變成 init 參數 —— 它們本來就是輸入,
不是相依,擠在 Dependency struct 裡混淆了兩者。

toggleFavorite 不再字串化 id。它仍然依儲存而非依 viewState.isFavorite 決定
方向,那個判斷有測試釘住(儲存與畫面狀態分歧時依儲存決定方向)。

Coordinator 的建構點跟著改 —— spec 的影響範圍漏了這個檔案。"
```

---

### Task 5: 刪除三個 protocol、三個 mock 與未使用的成員

前四步已經沒有任何呼叫端在用舊的 protocol。這一步把它們清掉。

**Files:**
- Modify: `Pokmon/Model/Dependencies.swift`
- Modify: `Pokmon/Model/NetworkService/NetworkService.swift`
- Modify: `PokmonTests/UserDefaultStoreTests.swift`
- Rename: `Pokmon/Model/UseCase/FavoriteUseCase.swift` → `Pokmon/Model/UseCase/UserDefaultStore.swift`（`git mv`）
- Delete: `Pokmon/Model/UseCase/ListUseCase.swift`
- Delete: `PokmonTests/Mock/MockService.swift`
- Delete: `PokmonTests/Mock/MockFavoriteUseCase.swift`
- Delete: `PokmonTests/Mock/MockListUSeCase.swift`

**Interfaces:**
- Produces: `Dependencies` 只剩 `api` 與 `favorites`
- Produces: `NetworkService` protocol 不再存在；`APIService` actor 保留為具體型別
- Produces: `FavoriteUseCase` protocol 不再存在；`UserDefaultStore` 保留為具體型別，且不再有 `isEmpty`

- [ ] **Step 1: 精簡 `Dependencies`**

把 `Pokmon/Model/Dependencies.swift` 的 enum 主體改為只剩兩項，並刪除那段「正在被取代」的註解：

```swift
enum Dependencies {
    @TaskLocal static var api: PokemonAPIClient = .live
    @TaskLocal static var favorites: FavoritesClient = .live
}
```

檔頭的 doc comment 保留不動。

- [ ] **Step 2: 刪除 `NetworkService` protocol**

`Pokmon/Model/NetworkService/NetworkService.swift` 中，刪除：

```swift
protocol NetworkService: Sendable {
    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model
}
```

並把 `actor APIService: NetworkService {` 改為：

```swift
actor APIService {
```

`request` 方法本體、`makeRequest` 與 `static let share` 一律不動。它現在只有 `PokemonAPIClient.live` 一個呼叫端。

- [ ] **Step 3: 刪除 `FavoriteUseCase` protocol 並移除 `isEmpty`**

```bash
git mv Pokmon/Model/UseCase/FavoriteUseCase.swift Pokmon/Model/UseCase/UserDefaultStore.swift
```

在更名後的檔案中，刪除整個 protocol 宣告：

```swift
protocol FavoriteUseCase: AnyObject, Sendable {
    func insert(_ element: String)
    func isContain(_ element: String) -> Bool
    func remove(_ element: String)
    var isEmpty: Bool { get }
    func synchronize()
}
```

把 `final class UserDefaultStore: FavoriteUseCase {` 改為：

```swift
final class UserDefaultStore: Sendable {
```

並刪除 `isEmpty` 這個計算屬性（零生產呼叫端）：

```swift
    var isEmpty: Bool {
        collection.withLock(\.isEmpty)
    }
```

同時把檔頭的註解第二行由 `//  FavoriteUseCase.swift` 改為 `//  UserDefaultStore.swift`。

- [ ] **Step 4: 更新 pbxproj 的檔名並移除刪除檔案的引用**

更名後 pbxproj 中 `FavoriteUseCase.swift` 的 `PBXFileReference` 的 `path` 要改為 `UserDefaultStore.swift`，註解也要跟著改。

刪除 `ListUseCase.swift`、`MockService.swift`、`MockFavoriteUseCase.swift`、`MockListUSeCase.swift` 這四個檔案在 pbxproj 中的四處引用（每檔 4 處，共 16 處）。

跑 `plutil -lint Pokmon.xcodeproj/project.pbxproj` 確認結構完好。

- [ ] **Step 5: 更新 `UserDefaultStoreTests`**

`isEmpty` 已移除，把 `test_store()` 改為用 `isContain` 表達同樣的意圖：

```swift
    func test_store() {
        let value = "element1"
        XCTAssertFalse(sutStore.isContain(value))
        sutStore.insert(value)
        sutStore.insert(value)
        XCTAssertTrue(sutStore.isContain(value))
        sutStore.remove("")
        XCTAssertTrue(sutStore.isContain(value))
        sutStore.remove(value)
        XCTAssertFalse(sutStore.isContain(value))

        sutStore.insert(value)
        sutStore.synchronize()

        // 插入兩次只會存成一筆 —— 這條斷言守著集合語義
        XCTAssertEqual(injectUserDefault.stringArray(forKey: testKey), [value])
    }
```

`remove("")` 之後改斷言 `isContain(value)` 仍為 true，表達的是「移除不存在的元素不影響既有內容」，與原本 `isEmpty` 仍為 false 等價。

- [ ] **Step 6: 終局檢查**

```bash
git grep -n "any NetworkService\|any FavoriteUseCase\|any ListUsecase\|@unchecked Sendable" -- Pokmon PokmonTests
```

Expected: 無任何輸出

```bash
git grep -n "Dependencies.network\|Dependencies.favorite\b\|Dependencies.list" -- Pokmon PokmonTests
```

Expected: 無任何輸出

- [ ] **Step 7: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED，app 端零警告

Run: TEST
Expected: TEST SUCCEEDED，26 個單元測試全過

- [ ] **Step 8: 在模擬器上做一次回歸**

沿用 Task 3 Step 8 的安裝與截圖指令。

Expected: 列表載入、每格顯示名稱與縮圖、屬性標籤與邊框色正常。需要點擊的項目（切換版型、進詳情頁、收藏星號、返回回填、收藏過濾）留給使用者驗證，在報告中明確列出哪些驗了、哪些沒驗。

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "delete the three UseCase protocols and their mocks

前四步之後已經沒有任何呼叫端在用它們。三個 protocol 各自只有一個實作、
沒有多型需求 —— 存在的唯一理由是讓測試能替換,Client 接手之後就沒有理由了。

三個 mock class 的 @unchecked Sendable 隨之消失。那是前一個計畫 Task 1 留下、
reviewer 標記為 deferred 的技術債,理由是「沒有任何東西強制那個『只在
MainActor 用』的假設」。現在 Sendable 由編譯器保證。

UserDefaultStore.isEmpty 零生產呼叫端,一併移除;它的測試斷言改用 isContain
表達同樣的意圖。檔名跟著改為 UserDefaultStore.swift。"
```

---

## Self-Review

**Spec coverage**

| Spec 章節 | 對應 Task |
|---|---|
| §3.1 兩個 Client 與 live | Task 1 Step 1–2 |
| §3.2 id 用 `Int`、`Endpoint` 退回 client | Task 1（live 內字串化）、Task 2 Step 1、Task 3 Step 3、Task 4 Step 2 |
| §3.3 刪除 `ListUsecase` | Task 3 Step 2（Store 自己 map）、Task 5（刪檔） |
| §3.4 Store 不再包 `Dependency` | Task 3 Step 1、4；Task 4 Step 1、3 |
| §3.5 三個 mock 全刪、`Recorder` | Task 1 Step 4（建立）、Task 2/3/4（使用）、Task 5（刪 mock） |
| §3.6 移除 `isEmpty` | Task 5 Step 3、5 |
| §4 影響範圍 | Task 1–5 全部；**新增 `CoordinatorProcotocol.swift`，見下** |
| §6 驗證 | 每個 Task 最後兩步；Task 5 Step 6 的終局檢查 |

**偏離 spec 一處**：spec §4 的「修改」清單漏了
`Pokmon/Feature/CoordinatorProcotocol.swift`。它是 `PokemonDetailStore` 的唯一
生產建構點，`Dependency` struct 刪除後必須跟著改。已納入 Task 4 Step 4，並在
該 Task 的 commit message 中註明。spec 的檔案數應為「修改 10」而非 9。

**Placeholder scan**：無 TBD / TODO；每個程式碼步驟都附完整可編譯的程式碼。

**Type consistency**

- `PokemonAPIClient` 的三個欄位名（`list` / `pokemon` / `species`）在 Task 2、3、4 的測試 helper 與 Store 呼叫端一致
- `FavoritesClient` 的四個欄位名（`contains` / `add` / `remove` / `synchronize`）在 Task 3、4 一致；`syncFavorites` 用 `contains`、`toggleFavorite` 用 `contains`/`add`/`remove`、`viewWillDisappear` 用 `synchronize`
- `Recorder<Value: Sendable>` 的 `record(_:)` / `recorded` / `count` 在 Task 2、3、4 的用法一致
- `CellViewModel.init(source:api:sepies:pokemon:)` — Task 2 定義，Task 3 Step 2（Store 內映射）與 Step 6（測試）使用
- `PokemonListStore.init(coordinator:api:favorites:)` — Task 3 定義，同 Task 的 `SceneDelegate` 與測試使用
- `PokemonDetailStore.init(pokemon:species:api:favorites:)` — Task 4 定義，同 Task 的 `Coordinator` 與測試使用
- `Dependencies.api` / `.favorites` — Task 1 新增，Task 2–4 作為預設參數引用，Task 5 移除舊三項

**一個刻意的設計選擇值得標記**：Task 3、4 的測試用 `Recorder` 兼作「可變旗標」
（`contains.recorded.last`）。這是把記錄器當狀態容器用，略微超出它的命名。
替代做法是再引入一個 `Flag` 型別，但為一兩處用法多一個測試型別不划算。
若日後這種用法變多，那就是抽出 `Flag` 的訊號。

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-01-usecase-to-client.md`.
