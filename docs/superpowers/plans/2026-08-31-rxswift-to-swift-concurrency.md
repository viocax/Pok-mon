# RxSwift 全面退場 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 Pokmon App 的 RxSwift、Combine、Swinject 三個相依完全移除，改用 Swift Concurrency + Observation + `@TaskLocal`，並在 Swift 6 語言模式下通過建置與測試，同時產出 UIKit → Concurrency 的遷移講稿。

**Architecture:** `@Observable @MainActor` 的 Store 持有 `viewState: State`，UIKit 端以 `withObservationTracking` 包裝的 `observe { }` 訂閱；非同步工作由 `Task` handle 管理生命週期；相依以 `@TaskLocal` 提供預設值，並在 `Dependency.init` 當下快照為 `let`。

**Tech Stack:** Swift 6.2 / Xcode 26、UIKit、Observation（iOS 17+）、Swift Testing、Alamofire、Kingfisher。

**Spec:** `docs/superpowers/specs/2026-08-31-rxswift-to-swift-concurrency-design.md`

## Global Constraints

- 分支：`concurrency`。每個 Task 結束時 commit。
- 部署目標 `IPHONEOS_DEPLOYMENT_TARGET = 17.2`，不得使用 iOS 18+ API（例如 `Synchronization.Mutex`、`Observations` AsyncSequence）。
- 最終相依只允許 `Alamofire` 與 `Kingfisher`。禁止新增任何第三方套件。
- 禁止出現 `import RxSwift`、`import RxCocoa`、`import RxRelay`、`import Combine`、`import Swinject`。
- 禁止使用 `Task.detached`（不繼承 `@TaskLocal`）。
- 每個 Task 的最後一步都必須跑**完整** scheme 的建置與測試，不得只用 `-only-testing:` 的局部通過作為驗證。

建置與測試指令（本文件後續以 BUILD / TEST 代稱）：

```bash
# BUILD
xcodebuild build -workspace Pokmon.xcworkspace -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# TEST
xcodebuild test -workspace Pokmon.xcworkspace -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## File Structure

**新增**

| 路徑 | 責任 |
|---|---|
| `Pokmon/Model/Dependencies.swift` | 唯一的相依來源，三個 `@TaskLocal` 靜態屬性 |
| `Pokmon/Extension/UIResponder++Observe.swift` | `observe(_:)` — 把 `withObservationTracking` 包成會自我重新掛載的訂閱 |
| `Pokmon/Extension/UIView++State.swift` | `setLoading(_:)` / `setEmpty(_:)` — 取代 Rx 的 `Reactive.Binder` |
| `PokmonTests/Stub/Stub.swift` | 測試用的 response 樣本 |
| `PokmonTests/PokemonListStoreTests.swift` | List Store 行為測試 |
| `PokmonTests/PokemonDetailStoreTests.swift` | Detail Store 行為測試 |
| `docs/uikit-to-concurrency/*.md` | 講稿 11 章 |

**刪除**

| 路徑 | 原因 |
|---|---|
| `Pokmon/Model/InjectObject.swift` | Swinject 容器與 `@Injected`，由 `Dependencies.swift` 取代 |
| `Pokmon/Model/ErrorTracker.swift` | Rx 專用，且已無呼叫端 |
| `Pokmon/Model/HUDTracker.swift` | Rx 專用，僅服務 Rx 版 `CellViewModel` |
| `Pokmon/Feature/List/CellViewModel+Hashable.swift` | 併回 `CellViewModel.swift` |
| `PokmonTests/Mock/InjectObjectTestable.swift` | 全域容器的測試後門，改用建構子傳入 |

**修改**：兩個 Store、兩個 ViewController、`PokemonCell`、`PokemonDetailInfoCell`、`CellViewModel`、`EmptyView`、`IndicatorView`、`NetworkService`、`Endpoint`、`FavoriteUseCase`、`ListUseCase`、`SceneDelegate`、四個 Mock、`CellViewModelTests`、`UserDefaultWrapperTests`、`Podfile`、`project.pbxproj`。

---

### Task 1: 相依注入改用 `@TaskLocal`，移除 Swinject

**Files:**
- Create: `Pokmon/Model/Dependencies.swift`
- Modify: `Pokmon/Model/NetworkService/NetworkService.swift`
- Modify: `Pokmon/Model/UseCase/FavoriteUseCase.swift`
- Modify: `Pokmon/Model/UseCase/ListUseCase.swift`
- Modify: `Pokmon/Feature/List/PokemonListStore.swift`（`Dependency` 區塊）
- Modify: `Pokmon/Feature/Detail/PokemonDetailStore.swift`（`Dependency` 區塊）
- Modify: `Pokmon/Feature/List/Cell/CellViewModel.swift`（`Dependency` 區塊）
- Modify: `Pokmon/SceneDelegate.swift`
- Modify: `Podfile`
- Delete: `Pokmon/Model/InjectObject.swift`
- Delete: `PokmonTests/Mock/InjectObjectTestable.swift`
- Test: `PokmonTests/UserDefaultWrapperTests.swift`（更名為 `UserDefaultStoreTests.swift`）
- Test: `PokmonTests/CellViewModelTests.swift`（僅更新 mock 注入方式）
- Modify: `PokmonTests/Mock/MockService.swift`、`MockFavoriteUseCase.swift`、`MockListUSeCase.swift`

**Interfaces:**
- Produces: `enum Dependencies`，含 `@TaskLocal static var network: any NetworkService`、`favorite: any FavoriteUseCase`、`list: any ListUsecase`
- Produces: `final class UserDefaultStore: FavoriteUseCase`，含 `static let shared`、`init(userDefault: UserDefaults = .standard, key: String = "com.drake.faviorite")`
- Produces: `PokemonListStore.Dependency.init(coordinator:service:favorite:list:)`、`PokemonDetailStore.Dependency.init(spiecs:pokemon:service:favorite:)`、`CellViewModel.Dependency.init(sepies:pokemon:source:service:)`——後三個參數皆有預設值，預設值即為讀取 `Dependencies` 的當下快照

- [ ] **Step 1: 把 `UserDefaultWrapper` 改成 lock 保護的 `UserDefaultStore`**

`@TaskLocal` 要求 `Value: Sendable`，所以 `FavoriteUseCase` 必須是 Sendable 協定。改用 `OSAllocatedUnfairLock`（iOS 16+）而非 actor，是為了讓 `isContain` 維持同步——改成 async 會一路污染 Store 的同步流程。

改寫 `Pokmon/Model/UseCase/FavoriteUseCase.swift` 全檔：

```swift
//
//  FavoriteUseCase.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import Foundation
import os

protocol FavoriteUseCase: AnyObject, Sendable {
    func insert(_ element: String)
    func isContain(_ element: String) -> Bool
    func remove(_ element: String)
    var isEmpty: Bool { get }
    func synchronize()
}

final class UserDefaultStore: FavoriteUseCase {

    static let shared: UserDefaultStore = .init()

    /// UserDefaults 的文件保證 thread-safe，但型別本身沒有 Sendable 標註
    nonisolated(unsafe) private let userDefault: UserDefaults
    private let key: String
    private let collection: OSAllocatedUnfairLock<Set<String>>

    init(userDefault: UserDefaults = .standard, key: String = "com.drake.faviorite") {
        self.userDefault = userDefault
        self.key = key
        self.collection = .init(initialState: Set(userDefault.stringArray(forKey: key) ?? []))
    }

    var isEmpty: Bool {
        collection.withLock(\.isEmpty)
    }

    func insert(_ element: String) {
        collection.withLock { _ = $0.insert(element) }
    }

    func remove(_ element: String) {
        collection.withLock { _ = $0.remove(element) }
    }

    func isContain(_ element: String) -> Bool {
        collection.withLock { $0.contains(element) }
    }

    func synchronize() {
        let snapshot = collection.withLock { Array($0) }
        userDefault.setValue(snapshot, forKey: key)
    }
}
```

- [ ] **Step 2: 更新既有的 UserDefault 測試並確認它先失敗**

把 `PokmonTests/UserDefaultWrapperTests.swift` 更名為 `PokmonTests/UserDefaultStoreTests.swift`（`git mv`），內容改為：

```swift
//
//  UserDefaultStoreTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import XCTest
@testable import Pokmon

final class UserDefaultStoreTests: XCTestCase {

    var sutStore: UserDefaultStore!
    let testKey: String = "com.drake.Test"
    var injectUserDefault: UserDefaults!

    override func setUp() {
        super.setUp()
        injectUserDefault = .init(suiteName: "com.drake.test")!
        injectUserDefault.removeObject(forKey: testKey)
        sutStore = .init(userDefault: injectUserDefault, key: testKey)
    }

    func test_store() {
        let value = "element1"
        XCTAssertFalse(sutStore.isContain(value))
        XCTAssertTrue(sutStore.isEmpty)
        sutStore.insert(value)
        sutStore.insert(value)
        XCTAssertTrue(sutStore.isContain(value))
        XCTAssertFalse(sutStore.isEmpty)
        sutStore.remove("")
        XCTAssertFalse(sutStore.isEmpty)
        sutStore.remove(value)
        XCTAssertTrue(sutStore.isEmpty)

        sutStore.insert(value)
        sutStore.synchronize()

        XCTAssertEqual(injectUserDefault.stringArray(forKey: testKey), [value])
    }
}
```

原版 `setUp` 沒有清空 suite，是靠測試順序僥倖通過的；新增的 `removeObject(forKey:)` 讓它真正可重複執行。

Run: TEST
Expected: 失敗，`cannot find 'UserDefaultStore' in scope` 之外還有 `InjectObject` 相關錯誤（此時 Step 3 之後才會全綠）。這一步只確認測試檔已納入編譯。

- [ ] **Step 3: 新增 `Dependencies.swift`**

Create `Pokmon/Model/Dependencies.swift`：

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
/// 讀取規則：**只在 `Dependency.init` 讀一次並存成 `let`**。
/// `@TaskLocal` 的值是在 `Task` 建立當下捕捉的，若沿用「每次存取才 resolve」
/// 的語義，測試會踩到「Task 建立時機決定讀到誰」——在 `withValue { }` 外
/// 建立的 `Task` 會讀到 live 實作而打到真實網路。
enum Dependencies {
    @TaskLocal static var network: any NetworkService = APIService.share
    @TaskLocal static var favorite: any FavoriteUseCase = UserDefaultStore.shared
    @TaskLocal static var list: any ListUsecase = ListUseCaseImp()
}
```

- [ ] **Step 4: 讓三個協定滿足 `Sendable`**

`Pokmon/Model/UseCase/ListUseCase.swift`：

```swift
protocol ListUsecase: Sendable {
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel]
}
```

`Pokmon/Model/NetworkService/NetworkService.swift` — 只改協定宣告與 class 宣告兩行，`request` 的兩個實作維持原樣：

```swift
protocol NetworkService: Sendable {
    func request<T: Endpoint>(_ endpoint: T) -> Observable<T.Model>
    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model
}

/// Alamofire 的 `Session` 文件保證 thread-safe，但 5.8.1 沒有 Sendable 標註。
/// Task 7 移除 Rx 版 `request` 之後，這個型別會改成 `actor`，屆時可拿掉
/// `@unchecked`——現在還不行，因為 Rx 版是同步回傳，放進 actor 會強迫呼叫端 await。
final class APIService: NetworkService, @unchecked Sendable {
```

- [ ] **Step 5: 三個 `Dependency` 改成建構時快照**

`Pokmon/Feature/List/PokemonListStore.swift` 的 `Dependency`：

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
        ) {
            self.coordinator = coordinator
            self.service = service
            self.favorite = favorite
            self.list = list
        }
    }
```

`Pokmon/Feature/Detail/PokemonDetailStore.swift` 的 `Dependency`：

```swift
    struct Dependency {
        var number: Int { pokemon.id }
        let pokemon: PokmonResponse
        var spiecs: PokemonSpeciesResponse?
        let service: any NetworkService
        let favorite: any FavoriteUseCase

        init(
            spiecs: PokemonSpeciesResponse?,
            pokemon: PokmonResponse,
            service: any NetworkService = Dependencies.network,
            favorite: any FavoriteUseCase = Dependencies.favorite
        ) {
            self.spiecs = spiecs
            self.pokemon = pokemon
            self.service = service
            self.favorite = favorite
        }
    }
```

`Pokmon/Feature/List/Cell/CellViewModel.swift` 的 `Dependency`（維持 class，`transform` 尚未動）：

```swift
    class Dependency {
        var number: Int { source.number }
        var sepies: PokemonSpeciesResponse?
        var pokemon: PokmonResponse?
        let source: PokemonListResponse.Item
        let service: any NetworkService

        init(
            sepies: PokemonSpeciesResponse? = nil,
            pokemon: PokmonResponse? = nil,
            source: PokemonListResponse.Item,
            service: any NetworkService = Dependencies.network
        ) {
            self.sepies = sepies
            self.pokemon = pokemon
            self.source = source
            self.service = service
        }
    }
```

- [ ] **Step 6: 刪除 Swinject 的殘留並更新 `SceneDelegate`**

```bash
git rm Pokmon/Model/InjectObject.swift PokmonTests/Mock/InjectObjectTestable.swift
```

`Pokmon/SceneDelegate.swift` 中刪除這兩行：

```swift
        // configuration
        InjectObject.shared.configuration()
```

並把 `sceneWillResignActive` 內的 `UserDefaultWrapper.share.synchronize()` 改為：

```swift
        Dependencies.favorite.synchronize()
```

- [ ] **Step 7: Mock 改為滿足 `Sendable`**

三個測試替身都只在 MainActor 上被使用，但協定的同步需求讓 `@MainActor` 標註在此階段會產生警告（Rx 版 `request` 是同步需求）。先用 `@unchecked Sendable`，Task 7 移除 Rx 之後再收斂。

`PokmonTests/Mock/MockService.swift`：

```swift
//
//  MockService.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
import RxSwift
@testable import Pokmon

/// 測試替身只在 MainActor 上使用，不做跨執行緒存取
class MockService: NetworkService, @unchecked Sendable {

    var injectRequest: Observable<Any> = .empty()
    func request<T>(_ endpoint: T) -> RxSwift.Observable<T.Model> where T: Pokmon.Endpoint {
        return injectRequest.compactMap { $0 as? T.Model }
    }

    var injectAsyncResponse: Any?
    var injectAsyncError: Error?
    private(set) var requestedPaths: [String] = []

    func request<T>(_ endpoint: T) async throws -> T.Model where T: Pokmon.Endpoint {
        requestedPaths.append(endpoint.path)
        if let injectAsyncError {
            throw injectAsyncError
        }
        guard let model = injectAsyncResponse as? T.Model else {
            throw PkError.badRequest
        }
        return model
    }
}
```

`PokmonTests/Mock/MockFavoriteUseCase.swift` — 刪除 `import RxSwift`，class 宣告改為：

```swift
/// 測試替身只在 MainActor 上使用，不做跨執行緒存取
class MockFavoriteUseCase: FavoriteUseCase, @unchecked Sendable {
```

`PokmonTests/Mock/MockListUSeCase.swift` — class 宣告改為：

```swift
/// 測試替身只在 MainActor 上使用，不做跨執行緒存取
class MockListUseCase: ListUsecase, @unchecked Sendable {
```

- [ ] **Step 8: `CellViewModelTests` 改用建構子傳入 mock**

`PokmonTests/CellViewModelTests.swift` 的 `setUp` 中，刪除這一行：

```swift
        mockDependency.mock(dependency: mockNetworkService, NetworkService.self)
```

並把 `mockDependency` 的建立改為：

```swift
        let mockDependency = CellViewModel.Dependency(source: mockSource, service: mockNetworkService)
```

同檔 `test_viewModel_PokemonShareData` 內的：

```swift
        viewModel = .init(dependency: .init(sepies: nil, pokemon: mockPokemon, source: mockSource))
```

維持不變（`service` 走預設值即可，該測試不發請求）。

- [ ] **Step 9: Podfile 移除 Swinject 並重新安裝**

`Podfile` 中刪除 `  pod 'Swinject'` 這一行。

```bash
pod install
```

- [ ] **Step 10: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED，`UserDefaultStoreTests` 與 `CellViewModelTests` 皆通過

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "replace Swinject container with @TaskLocal dependencies

相依從全域容器改成 @TaskLocal，並在 Dependency.init 當下快照成 let。
不快照的話 @TaskLocal 會在 Task 建立時才捕捉，測試就得盯著 Task 的
建立時機才能確定讀到 mock 還是 live。

FavoriteUseCase 為了滿足 @TaskLocal 的 Sendable 需求改用
OSAllocatedUnfairLock 而非 actor，讓 isContain 維持同步——改 async
會一路污染 Store 的同步流程。"
```

---

### Task 2: 補回兩個 Store 的測試

Store 目前零覆蓋。先蓋好安全網，後續四個 Task 的重構才有護欄。

**Files:**
- Create: `PokmonTests/Stub/Stub.swift`
- Create: `PokmonTests/PokemonListStoreTests.swift`
- Create: `PokmonTests/PokemonDetailStoreTests.swift`
- Modify: `Pokmon/Feature/List/PokemonListStore.swift`（把 task handle 開放給測試）
- Modify: `Pokmon/Feature/Detail/PokemonDetailStore.swift`（同上）

**Interfaces:**
- Consumes: Task 1 的 `PokemonListStore.Dependency.init(coordinator:service:favorite:list:)` 與 `PokemonDetailStore.Dependency.init(spiecs:pokemon:service:favorite:)`
- Produces: `enum Stub`，含 `item(_:name:)`、`listResponse(numbers:nextOffset:)`、`pokemon(id:name:)`、`species(cnName:)`
- Produces: `PokemonListStore.loadTask` / `.detailTask`、`PokemonDetailStore.loadTask` 皆為 `private(set) var`，供測試 `await`

- [ ] **Step 1: 建立 Stub**

Create `PokmonTests/Stub/Stub.swift`：

```swift
//
//  Stub.swift
//  PokmonTests
//
//  Created by drake on 2026/8/31.
//

import Foundation
@testable import Pokmon

enum Stub {

    static func item(_ number: Int, name: String = "mockName") throws -> PokemonListResponse.Item {
        try .init(.init(name: name, url: "https://pokeapi.co/api/v2/pokemon/\(number)"))
    }

    static func listResponse(numbers: [Int], nextOffset: Int?) throws -> PokemonListResponse {
        .init(
            results: try numbers.map { try item($0) },
            offset: nextOffset,
            totalCount: 1000
        )
    }

    static func pokemon(id: Int, name: String = "bulbasaur") -> PokmonResponse {
        .init(
            id: id,
            name: name,
            height: 7,
            weight: 69,
            sprites: .init(thumbnail: "https://example.com/\(id).png"),
            species: .init(name: "species", url: "url"),
            types: [],
            stats: []
        )
    }

    static func species(cnName: String = "妙蛙種子") -> PokemonSpeciesResponse {
        .init(
            color: .init(name: "green", url: ""),
            flavorEntitys: [],
            names: [.init(language: .init(name: "zh-Hans", url: ""), name: cnName)]
        )
    }
}
```

`PokmonResponse.Sprite.init(thumbnail:)` 在 `#if DEBUG` 之下，測試以 Debug 組建，可用。

- [ ] **Step 2: 把 task handle 開放給測試**

`PokemonListStore` 中：

```swift
    private var loadTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
```

改為（測試需要 `await` 這些 handle 才能等到非同步流程結束）：

```swift
    /// `private(set)` 是為了讓測試能 await 到非同步流程結束
    private(set) var loadTask: Task<Void, Never>?
    private(set) var detailTask: Task<Void, Never>?
```

`PokemonDetailStore` 中 `private var loadTask: Task<Void, Never>?` 比照改為 `private(set) var loadTask: Task<Void, Never>?`。

- [ ] **Step 3: 寫 List Store 的失敗測試**

Create `PokmonTests/PokemonListStoreTests.swift`：

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

    private func makeStore(
        service: MockService = .init(),
        favorite: MockFavoriteUseCase = .init(),
        list: MockListUseCase = .init(),
        coordinator: MockCoordinator = .init()
    ) -> PokemonListStore {
        PokemonListStore(
            dependency: .init(
                coordinator: coordinator,
                service: service,
                favorite: favorite,
                list: list
            )
        )
    }

    @Test func 載入成功時填入cells與nextOffset() async throws {
        let service = MockService()
        service.injectAsyncResponse = try Stub.listResponse(numbers: [1, 2, 3], nextOffset: 20)
        let list = MockListUseCase()
        list.injectCellViewModels = [
            CellViewModel(dependency: .init(source: try Stub.item(1))),
            CellViewModel(dependency: .init(source: try Stub.item(2))),
            CellViewModel(dependency: .init(source: try Stub.item(3)))
        ]
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(service: service, favorite: favorite, list: list)
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(store.viewState.cells.count == 3)
        #expect(store.viewState.nextOffset == 20)
        #expect(store.viewState.isLoading == false)
        #expect(store.viewState.alert == nil)
    }

    @Test func 載入失敗時設定alert() async throws {
        let service = MockService()
        service.injectAsyncError = PkError.badRequest

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(store.viewState.alert != nil)
        #expect(store.viewState.cells.isEmpty)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 已經到底時loadMore不再發請求() async throws {
        let service = MockService()
        service.injectAsyncResponse = try Stub.listResponse(numbers: [1], nextOffset: nil)
        let list = MockListUseCase()
        list.injectCellViewModels = [CellViewModel(dependency: .init(source: try Stub.item(1)))]

        let store = makeStore(service: service, list: list)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.nextOffset == nil)
        #expect(store.viewState.hasNextPage == false)

        let countAfterFirstLoad = service.requestedPaths.count
        store.send(.loadMore)
        await store.loadTask?.value

        #expect(service.requestedPaths.count == countAfterFirstLoad)
    }

    @Test func 收藏過濾會改變displayCells() async throws {
        let service = MockService()
        service.injectAsyncResponse = try Stub.listResponse(numbers: [1, 2], nextOffset: 20)
        let list = MockListUseCase()
        list.injectCellViewModels = [
            CellViewModel(dependency: .init(source: try Stub.item(1))),
            CellViewModel(dependency: .init(source: try Stub.item(2)))
        ]
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(service: service, favorite: favorite, list: list)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.displayCells.count == 2)

        favorite.injectIsContain = true
        store.send(.tapFavorite)

        #expect(store.viewState.isFavoriteFilterOn == true)
        #expect(store.viewState.displayCells.count == 2)

        favorite.injectIsContain = false
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
        let service = MockService()
        service.injectAsyncError = PkError.badRequest

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        store.send(.dismissAlert)
        #expect(store.viewState.alert == nil)
    }
}
```

- [ ] **Step 4: 執行 List Store 測試**

Run: TEST
Expected: TEST SUCCEEDED

這批測試是**特徵測試**（characterization test），描述的是 Store 目前既有的正確行為，用途是替後面四個 Task 的重構當護欄，而不是驅動新功能——所以它應該一次就綠。

若有任何一項失敗，代表 Store 有既存缺陷。**先停下來修 Store 再往下**，不要改測試去迎合現況：把缺陷帶進後續重構會讓失敗的歸因變得不可能。

- [ ] **Step 5: 寫 Detail Store 的測試**

Create `PokmonTests/PokemonDetailStoreTests.swift`：

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

    private func makeStore(
        spiecs: PokemonSpeciesResponse? = nil,
        service: MockService = .init(),
        favorite: MockFavoriteUseCase = .init()
    ) -> PokemonDetailStore {
        PokemonDetailStore(
            dependency: .init(
                spiecs: spiecs,
                pokemon: Stub.pokemon(id: 1),
                service: service,
                favorite: favorite
            )
        )
    }

    @Test func 初始化時帶入標題與收藏狀態() {
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = true

        let store = makeStore(favorite: favorite)

        #expect(store.viewState.title == "No.1")
        #expect(store.viewState.isFavorite == true)
    }

    @Test func species已存在時onAppear不發請求() async {
        let service = MockService()
        let store = makeStore(spiecs: Stub.species(), service: service)

        store.send(.onAppear)
        await store.loadTask?.value

        #expect(service.requestedPaths.isEmpty)
        #expect(store.viewState.isEmpty == false)
    }

    @Test func species不存在時onAppear發請求並填入() async {
        let service = MockService()
        service.injectAsyncResponse = Stub.species()

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(service.requestedPaths == ["pokemon-species/1"])
        #expect(store.viewState.species != nil)
        #expect(store.viewState.rows.count == 2)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 載入失敗時設定alert且dismiss會重試() async {
        let service = MockService()
        service.injectAsyncError = PkError.badRequest

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        service.injectAsyncError = nil
        service.injectAsyncResponse = Stub.species()
        store.send(.dismissAlert)
        await store.loadTask?.value

        #expect(store.viewState.alert == nil)
        #expect(store.viewState.species != nil)
    }

    @Test func 切換收藏() {
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(favorite: favorite)
        #expect(store.viewState.isFavorite == false)

        favorite.injectIsContain = true
        store.send(.tapFavorite(1))

        #expect(favorite.recordInsert == 1)
        #expect(store.viewState.isFavorite == true)
    }

    @Test func viewWillDisappear觸發synchronize() {
        let favorite = MockFavoriteUseCase()
        let store = makeStore(favorite: favorite)

        store.send(.viewWillDisappear)

        #expect(favorite.recordSynchronize == 1)
    }
}
```

- [ ] **Step 6: 執行完整測試**

Run: TEST
Expected: TEST SUCCEEDED，兩個新 Suite 共 12 個測試全部通過

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "add Swift Testing coverage for both stores

改寫 Store 時把兩支 ViewModel 測試刪掉後一直沒補回來,Store 至今零覆蓋。
先把護欄補上,後面拔 Rx 的四個步驟才有東西擋。

用 Swift Testing 而非 XCTest,是因為 @Test func 本身就能 async,
等非同步流程結束只要 await store.loadTask?.value,不必繞
XCTestExpectation。"
```

---

### Task 3: 建立 Observation 綁定基礎設施

只新增，不刪除任何 Rx 程式碼。這一步結束後 Rx 與 Observation 並存，兩者都可用。

**Files:**
- Create: `Pokmon/Extension/UIResponder++Observe.swift`
- Create: `Pokmon/Extension/UIView++State.swift`

**Interfaces:**
- Produces: `UIResponder.observe(_ apply: @escaping @MainActor () -> Void)`
- Produces: `UIView.setLoading(_ isLoading: Bool)`、`UIView.setEmpty(_ isEmpty: Bool)`

- [ ] **Step 1: 新增 `observe` helper**

必須掛在 `UIResponder` 而非 `NSObject`：`NSObject` 不是 `Sendable`，在 `Task { @MainActor }` 中捕捉 `self` 會編譯失敗；`UIResponder` 在 UIKit 中已標 `@MainActor`，捕捉才成立。

Create `Pokmon/Extension/UIResponder++Observe.swift`：

```swift
//
//  UIResponder++Observe.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import Observation
import UIKit

@MainActor
extension UIResponder {

    /// 取代 Combine 的 `sink` 與 Rx 的 `drive`。
    ///
    /// `withObservationTracking` 只會通知**一次**,所以 `onChange` 要把自己重新掛回去。
    /// `onChange` 是在值真正寫入**之前**觸發的(willSet 語義),因此不能在 `onChange`
    /// 裡直接讀新值——必須丟進 `Task` 等這一輪寫完再讀,重新掛載時 `apply` 讀到的
    /// 才是新值。
    func observe(_ apply: @escaping @MainActor () -> Void) {
        withObservationTracking(apply) {
            Task { @MainActor [weak self] in
                self?.observe(apply)
            }
        }
    }
}
```

- [ ] **Step 2: 新增非 Rx 版的 loading / empty 狀態切換**

Create `Pokmon/Extension/UIView++State.swift`：

```swift
//
//  UIView++State.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import UIKit

@MainActor
extension UIView {

    /// 取代 `view.rx.indicatorAnimator`
    func setLoading(_ isLoading: Bool) {
        if isLoading {
            let indicator: IndicatorView
            if let existed = subviews.first(where: { $0 is IndicatorView }) as? IndicatorView {
                indicator = existed
            } else {
                let added = IndicatorView()
                addSubview(added)
                added.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    added.leadingAnchor.constraint(equalTo: leadingAnchor),
                    added.trailingAnchor.constraint(equalTo: trailingAnchor),
                    added.bottomAnchor.constraint(equalTo: bottomAnchor),
                    added.topAnchor.constraint(equalTo: topAnchor)
                ])
                indicator = added
            }
            indicator.startAnimation()
        } else {
            let indicator = subviews.first(where: { $0 is IndicatorView }) as? IndicatorView
            indicator?.stopAnimation()
            indicator?.removeFromSuperview()
        }
    }

    /// 取代 `view.rx.isEmpty`
    func setEmpty(_ isEmpty: Bool) {
        let existed = subviews.first(where: { $0 is EmptyView })
        if isEmpty {
            guard existed == nil else { return }
            let added = EmptyView()
            addSubview(added)
            added.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                added.trailingAnchor.constraint(equalTo: trailingAnchor),
                added.leadingAnchor.constraint(equalTo: leadingAnchor),
                added.topAnchor.constraint(equalTo: topAnchor),
                added.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            existed?.removeFromSuperview()
        }
    }
}
```

兩個方法都是冪等的：重複以相同參數呼叫不會疊加 subview。這是 Task 4、5 能安全依賴「所有 observe closure 一起重跑」的前提。

- [ ] **Step 3: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "add observe helper and non-Rx view state extensions

observe 掛在 UIResponder 而不是 NSObject:NSObject 不是 Sendable,
在 Task { @MainActor } 裡捕捉 self 會編不過,UIResponder 已標 @MainActor 才行。

withObservationTracking 只通知一次,所以 onChange 要把自己重新掛回去;
又因為 onChange 是 willSet 語義,得丟進 Task 等值寫完才讀得到新值。"
```

---

### Task 4: `PokemonListStore` 與 List VC 改用 Observation

**Files:**
- Modify: `Pokmon/Feature/List/PokemonListStore.swift`
- Modify: `Pokmon/Feature/List/PokemonListViewController.swift`

**Interfaces:**
- Consumes: Task 3 的 `UIResponder.observe(_:)`、`UIView.setLoading(_:)`、`UIView.setEmpty(_:)`
- Produces: `PokemonListStore` 標記 `@Observable`，`viewState` 維持 `private(set) var`，對外型別不變

- [ ] **Step 1: Store 換掉 Combine**

`Pokmon/Feature/List/PokemonListStore.swift` 開頭的：

```swift
import Combine
import Foundation

@MainActor
final class PokemonListStore {
```

改為：

```swift
import Foundation
import Observation

@Observable
@MainActor
final class PokemonListStore {
```

並把：

```swift
    @Published private(set) var viewState: State = .init()
```

改為：

```swift
    private(set) var viewState: State = .init()
```

其餘邏輯完全不動。

**注意：Step 1 與 Step 2 必須一起完成才能編譯。** `@Observable` 移除了 `$viewState` 這個 projected value，VC 現有的 `store.$viewState` 會立刻失效。中間不設驗證點，直接做完 Step 2 再跑建置。

- [ ] **Step 2: VC 換掉 Combine**

`Pokmon/Feature/List/PokemonListViewController.swift` 開頭：

```swift
import Combine
import RxCocoa
import UIKit
```

改為：

```swift
import UIKit
```

刪除屬性：

```swift
    private var cancellables: Set<AnyCancellable> = .init()
```

新增屬性（`presentAlert` 是唯一不冪等的動作，需要自己擋重複）：

```swift
    /// State 是單一屬性,任何欄位變動都會讓所有 observe closure 重跑。
    /// 其餘動作都冪等,只有 present alert 需要自己防重複。
    private var presentedAlert: AlertState?
```

把整個 `bindStore()` 改為：

```swift
    func bindStore() {
        observe { [weak self] in
            guard let self else { return }
            self.applyLayout(isList: self.store.viewState.isListLayout)
        }

        observe { [weak self] in
            guard let self else { return }
            let isOn = self.store.viewState.isFavoriteFilterOn
            self.isFavoriteButton.setImage(.init(systemName: isOn ? "bookmark.fill" : "bookmark"), for: .normal)
        }

        observe { [weak self] in
            guard let self else { return }
            self.view.setLoading(self.store.viewState.isLoading)
        }

        observe { [weak self] in
            guard let self else { return }
            self.view.setEmpty(self.store.viewState.isEmpty)
        }

        observe { [weak self] in
            guard let self else { return }
            self.apply(self.store.viewState.displayCells)
        }

        observe { [weak self] in
            guard let self else { return }
            guard let alert = self.store.viewState.alert else {
                self.presentedAlert = nil
                return
            }
            guard self.presentedAlert != alert else { return }
            self.presentedAlert = alert
            self.presentAlert(alert) { [weak self] in self?.store.send(.dismissAlert) }
        }
    }
```

- [ ] **Step 3: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED

- [ ] **Step 4: 在模擬器上確認畫面行為**

```bash
xcrun simctl boot "iPhone 17" || true
xcodebuild -workspace Pokmon.xcworkspace -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath ./DD build
xcrun simctl install booted ./DD/Build/Products/Debug-iphonesimulator/Pokmon.app
xcrun simctl launch booted com.drake.Pokmon
```

Expected: 列表載入、切換 List/Grid、收藏過濾按鈕圖示切換皆與遷移前一致。若 bundle identifier 不同，以 `xcrun simctl listapps booted | grep -i pokmon` 取得正確值。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "move list store and view controller to Observation

@Published + sink 換成 @Observable + observe。

代價是 State 為單一屬性,任何欄位變動都會讓六個 observe closure 全部重跑。
逐一檢查過:applyLayout 已有相同版型的判斷、dataSource.apply 內部會 diff、
setLoading/setEmpty 冪等、title 指派冪等——只有 present alert 不冪等,
所以加了 presentedAlert 擋重複。"
```

---

### Task 5: `PokemonDetailStore`、Detail VC 與 InfoCell 改用 Observation

**Files:**
- Modify: `Pokmon/Feature/Detail/PokemonDetailStore.swift`
- Modify: `Pokmon/Feature/Detail/PokemonDeatilPageViewController.swift`
- Modify: `Pokmon/Feature/Detail/Cell/PokemonDetailInfoCell.swift`

**Interfaces:**
- Consumes: Task 3 的 `UIResponder.observe(_:)`、`UIView.setLoading(_:)`、`UIView.setEmpty(_:)`
- Produces: `PokemonDetailStore.Info` 的 `isFavorite` 欄位型別由 `AnyPublisher<Bool, Never>` 改為 `@MainActor () -> Bool`
- Produces: `PokemonDetailStore` 不再提供 `isFavoritePublisher`

- [ ] **Step 1: Store 換掉 Combine**

`Pokmon/Feature/Detail/PokemonDetailStore.swift` 開頭：

```swift
import Combine
import Foundation

@MainActor
final class PokemonDetailStore {
```

改為：

```swift
import Foundation
import Observation

@Observable
@MainActor
final class PokemonDetailStore {
```

把 `@Published private(set) var viewState: State = .init()` 改為 `private(set) var viewState: State = .init()`。

刪除整個計算屬性：

```swift
    var isFavoritePublisher: AnyPublisher<Bool, Never> {
        $viewState.map(\.isFavorite).removeDuplicates().eraseToAnyPublisher()
    }
```

把 `Info` 的宣告改為：

```swift
    struct Info {
        let pokemon: PokmonResponse
        let species: PokemonSpeciesResponse
        /// closure 在 cell 的 `observe` 內被呼叫,讀 store 屬性的動作就完成追蹤註冊,
        /// cell 因此不需要認識 Store 型別。這是 AnyPublisher 欄位的直接對應物。
        let isFavorite: @MainActor () -> Bool
    }
```

- [ ] **Step 2: InfoCell 換掉 Combine**

`Pokmon/Feature/Detail/Cell/PokemonDetailInfoCell.swift` 開頭：

```swift
import Combine
import UIKit

protocol PokemonDetailInfoCellDelegate: AnyObject {
```

改為：

```swift
import UIKit

@MainActor
protocol PokemonDetailInfoCellDelegate: AnyObject {
```

刪除屬性 `private var cancellables: Set<AnyCancellable> = .init()`，並把 `prepareForReuse` 中的 `cancellables = .init()` 一併刪除。

把 `bindView(_:)` 結尾的：

```swift
        info.isFavorite
            .sink { [weak self] isFavorite in
                self?.favoriteButton.setImage(isFavorite ? .init(named: "starFill") : .init(named: "starEmpty"), for: .normal)
            }
            .store(in: &cancellables)
```

改為：

```swift
        observe { [weak self] in
            let isFavorite = info.isFavorite()
            self?.favoriteButton.setImage(
                isFavorite ? .init(named: "starFill") : .init(named: "starEmpty"),
                for: .normal
            )
        }
```

- [ ] **Step 3: Detail VC 換掉 Combine**

`Pokmon/Feature/Detail/PokemonDeatilPageViewController.swift` 開頭：

```swift
import Combine
import RxCocoa
import UIKit
```

改為：

```swift
import UIKit
```

刪除屬性 `private var cancellables: Set<AnyCancellable> = .init()`，新增：

```swift
    private var presentedAlert: AlertState?
```

`makeDataSource()` 中建立 `Info` 的部分：

```swift
                (cell as? PokemonDetailInfoCell)?.bindView(
                    .init(
                        pokemon: self.store.pokemon,
                        species: species,
                        isFavorite: self.store.isFavoritePublisher
                    )
                )
```

改為：

```swift
                (cell as? PokemonDetailInfoCell)?.bindView(
                    .init(
                        pokemon: self.store.pokemon,
                        species: species,
                        isFavorite: { [store = self.store] in store.viewState.isFavorite }
                    )
                )
```

把整個 `bindStore()` 改為：

```swift
    func bindStore() {
        observe { [weak self] in
            guard let self else { return }
            self.title = self.store.viewState.title
        }

        observe { [weak self] in
            guard let self else { return }
            self.apply(self.store.viewState.rows)
        }

        observe { [weak self] in
            guard let self else { return }
            self.view.setEmpty(self.store.viewState.isEmpty)
        }

        observe { [weak self] in
            guard let self else { return }
            self.view.setLoading(self.store.viewState.isLoading)
        }

        observe { [weak self] in
            guard let self else { return }
            guard let alert = self.store.viewState.alert else {
                self.presentedAlert = nil
                return
            }
            guard self.presentedAlert != alert else { return }
            self.presentedAlert = alert
            self.presentAlert(alert) { [weak self] in self?.store.send(.dismissAlert) }
        }
    }
```

- [ ] **Step 4: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED

- [ ] **Step 5: 在模擬器上確認詳情頁**

沿用 Task 4 Step 4 的安裝與啟動指令。

Expected: 進入詳情頁後 species 載入、收藏星號點擊即時切換、返回列表後該筆的 species 已回填（再次進入不會重新請求）。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "move detail page to Observation

Info.isFavorite 從 AnyPublisher<Bool, Never> 換成 @MainActor () -> Bool。
closure 在 cell 的 observe 內被呼叫,讀 store 屬性當下就完成追蹤註冊,
效果跟訂閱 publisher 一樣,但 cell 不必認識 Store 型別。

Combine 至此完全退場,只剩 Rx。"
```

---

### Task 6: `CellViewModel` 與 `PokemonCell` 去 Rx

這是最後一哩，也是最需要小心的一步：`CellViewModel` 是 diffable data source 的 item identifier，`==` 與 `hash` 只看 `number`，資料載入完成時 snapshot 不變。原本靠 Rx 的 `drive` 直接把值推進 label，Rx 拿掉後改由 cell `observe` 這個 `@Observable` 的 view model。

**Files:**
- Modify: `Pokmon/Feature/List/Cell/CellViewModel.swift`
- Modify: `Pokmon/Feature/List/Cell/PokemonCell.swift`
- Modify: `Pokmon/Model/UseCase/ListUseCase.swift`
- Modify: `Pokmon/Model/PokemonShareData.swift`
- Modify: `Pokmon/Model/SpeciesUpdatable.swift`
- Modify: `PokmonTests/Mock/MockListUSeCase.swift`
- Modify: `PokmonTests/CellViewModelTests.swift`
- Modify: `PokmonTests/PokemonListStoreTests.swift`（`CellViewModel` 建構方式改變）
- Delete: `Pokmon/Model/HUDTracker.swift`
- Delete: `Pokmon/Model/ErrorTracker.swift`
- Delete: `Pokmon/Feature/List/CellViewModel+Hashable.swift`

**Interfaces:**
- Produces: `CellViewModel.init(source: PokemonListResponse.Item, service: any NetworkService = Dependencies.network, sepies: PokemonSpeciesResponse? = nil, pokemon: PokmonResponse? = nil)`
- Produces: `CellViewModel` 的顯示用計算屬性 `numberText: String`、`displayName: String`、`imageURL: String?`、`types: [any TypeCornerProtocol]`
- Produces: `CellViewModel.bindView()` 觸發載入、`CellViewModel.cancel()` 取消載入、`CellViewModel.loadTask` 供測試 await
- Produces: `ListUsecase.listConvertCell` 標記 `@MainActor`
- Produces: `PokemonShareData`、`SpeciesUpdatable` 標記 `@MainActor`

- [ ] **Step 1: 改寫 `CellViewModel`**

可變狀態必須是 `CellViewModel` 自己的 stored property——`@Observable` 只追蹤該 class 本身的儲存屬性，留在獨立的 `Dependency` class 裡 Observation 看不到。因此 `Dependency` 整個併入。

改寫 `Pokmon/Feature/List/Cell/CellViewModel.swift` 全檔：

```swift
//
//  CellViewModel.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import Foundation
import Observation

/// diffable data source 的 item identifier,所以 `==` 與 `hash` 只能看不變的 `number`。
/// 資料載入完成時 snapshot 因此不會變,cell 不會被重建——重刷改由 cell `observe`
/// 這個型別的可變屬性達成,取代原本 Rx `drive` 直接推值進 label 的做法。
@Observable
@MainActor
final class CellViewModel {

    nonisolated let number: Int

    private(set) var pokemon: PokmonResponse?
    private(set) var sepies: PokemonSpeciesResponse?
    private(set) var isLoading: Bool = false
    private(set) var loadTask: Task<Void, Never>?

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

    // MARK: - Output

    var numberText: String {
        "No.\(number)"
    }

    var displayName: String {
        if let pokemon {
            return pokemon.name
        }
        return isLoading ? "Loading..." : ""
    }

    var imageURL: String? {
        pokemon?.sprites.thumbnail
    }

    var types: [any TypeCornerProtocol] {
        pokemon?.types.map(\.type) ?? []
    }

    // MARK: - Input

    func bindView() {
        guard pokemon == nil, loadTask == nil else { return }

        loadTask = Task { [weak self] in
            guard let self else { return }

            self.isLoading = true
            defer { if !Task.isCancelled { self.isLoading = false } }

            let response = try? await self.service.request(PokemonEndpoint(id: "\(self.number)"))
            guard !Task.isCancelled else { return }

            self.pokemon = response
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
}

// MARK: - Hashable

extension CellViewModel: Hashable {

    /// 兩者都必須看同一個不變欄位,而且必須 nonisolated——`Hashable` 的需求不是
    /// MainActor 隔離的,碰不到 `pokemon` 這類可變狀態。
    nonisolated static func == (lhs: CellViewModel, rhs: CellViewModel) -> Bool {
        lhs.number == rhs.number
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

// MARK: - SpeciesUpdatable

extension CellViewModel: SpeciesUpdatable {
    func updateDetailPage(response sepies: PokemonSpeciesResponse) {
        self.sepies = sepies
    }
}

// MARK: - PokemonShareData

extension CellViewModel: PokemonShareData {

    func getPokemon() throws -> PokmonResponse {
        guard let pokemon else {
            throw PkError.pokemonDataNotYet
        }
        return pokemon
    }

    var spiecs: PokemonSpeciesResponse? {
        sepies
    }
}
```

- [ ] **Step 2: 刪除三個檔案**

```bash
git rm Pokmon/Model/HUDTracker.swift \
       Pokmon/Model/ErrorTracker.swift \
       Pokmon/Feature/List/CellViewModel+Hashable.swift
```

`ErrorTracker` 早已沒有呼叫端；`HUDTracker` 只服務 Step 1 刪掉的 Rx 版 `transform`。

- [ ] **Step 3: 兩個協定標記 `@MainActor`**

`Pokmon/Model/PokemonShareData.swift`：

```swift
@MainActor
protocol PokemonShareData {
    func getPokemon() throws -> PokmonResponse
    var spiecs: PokemonSpeciesResponse? { get }
}
```

`Pokmon/Model/SpeciesUpdatable.swift`：

```swift
@MainActor
protocol SpeciesUpdatable: AnyObject {
    func updateDetailPage(response sepies: PokemonSpeciesResponse)
}
```

- [ ] **Step 4: `ListUsecase` 標記 `@MainActor`**

`CellViewModel` 現在是 `@MainActor`，建構它的方法也必須是。

`Pokmon/Model/UseCase/ListUseCase.swift`：

```swift
protocol ListUsecase: Sendable {
    @MainActor
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel]
}

struct ListUseCaseImp: ListUsecase {
    @MainActor
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel] {
        items.map { CellViewModel(source: $0) }
    }
}
```

`PokmonTests/Mock/MockListUSeCase.swift`：

```swift
//
//  MockListUSeCase.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
@testable import Pokmon

/// 測試替身只在 MainActor 上使用,不做跨執行緒存取
class MockListUseCase: ListUsecase, @unchecked Sendable {
    var injectCellViewModels: [CellViewModel] = []

    @MainActor
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel] {
        injectCellViewModels
    }
}
```

- [ ] **Step 5: `PokemonCell` 換掉 Rx**

`Pokmon/Feature/List/Cell/PokemonCell.swift` 開頭：

```swift
import UIKit
import RxSwift
import RxCocoa
import Kingfisher
```

改為：

```swift
import UIKit
import Kingfisher
```

刪除屬性 `private var disposeBag: DisposeBag = .init()`，新增：

```swift
    private weak var viewModel: CellViewModel?
```

`prepareForReuse` 改為：

```swift
    override func prepareForReuse() {
        super.prepareForReuse()
        viewModel?.cancel()
        viewModel = nil
        thumbNailImageView.kf.cancelDownloadTask()
        thumbNailImageView.image = .placeHolder
    }
```

`bindView(_:)` 整個改為：

```swift
    func bindView(_ viewModel: CellViewModel) {
        self.viewModel = viewModel

        observe { [weak self] in
            self?.numberLabel.text = viewModel.numberText
        }

        observe { [weak self] in
            self?.nameLabel.text = viewModel.displayName
        }

        observe { [weak self] in
            guard let self, let urlString = viewModel.imageURL else { return }
            self.setImage(urlString)
        }

        observe { [weak self] in
            guard let self else { return }
            let types = viewModel.types
            guard !types.isEmpty else { return }
            self.cornerView.layer.borderColor = types.first?.color.cgColor
            self.typesStackView.setTypes(types)
            self.typesStackView.insertArrangedSubview(.init(), at: .zero)
            self.cornerView.gradientLayer.colors = [
                types.first?.color.cgColor ?? UIColor.white.cgColor,
                UIColor.white.cgColor
            ]
        }

        viewModel.bindView()
    }
```

把原本的 `var imageURL: Binder<String>` 計算屬性刪除，改為 private extension 中的方法：

```swift
    func setImage(_ urlString: String) {
        thumbNailImageView.kf.setImage(
            with: URL(string: urlString),
            placeholder: UIImage.placeHolder,
            completionHandler: { [weak self] result in
                self?.thumbNailImageView.stopRotate()
                if case .failure = result {
                    self?.thumbNailImageView.image = .errorImage
                }
            }
        )
    }
```

- [ ] **Step 6: 更新 `CellViewModelTests`**

`TestScheduler` 的虛擬時間換成 `await viewModel.loadTask?.value`。改寫 `PokmonTests/CellViewModelTests.swift` 全檔：

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

    @Test func 載入前後的輸出() async throws {
        let service = MockService()
        service.injectAsyncResponse = makePokemon()
        let viewModel = CellViewModel(source: try Stub.item(expectNumber), service: service)

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
        let service = MockService()
        let viewModel = CellViewModel(
            source: try Stub.item(expectNumber),
            service: service,
            pokemon: makePokemon()
        )

        viewModel.bindView()
        await viewModel.loadTask?.value

        #expect(service.requestedPaths.isEmpty)
        #expect(viewModel.displayName == expectName)
    }

    @Test func pokemon尚未載入時getPokemon拋錯() throws {
        let viewModel = CellViewModel(source: try Stub.item(expectNumber))

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
            pokemon: pokemon
        )

        #expect(try viewModel.getPokemon().id == pokemon.id)
    }

    @Test func updateDetailPage寫入species() throws {
        let viewModel = CellViewModel(source: try Stub.item(expectNumber))
        #expect(viewModel.spiecs == nil)

        viewModel.updateDetailPage(response: Stub.species())

        #expect(viewModel.spiecs != nil)
    }
}
```

- [ ] **Step 7: 更新 `PokemonListStoreTests` 的 `CellViewModel` 建構方式**

`PokmonTests/PokemonListStoreTests.swift` 中所有：

```swift
CellViewModel(dependency: .init(source: try Stub.item(1)))
```

改為：

```swift
CellViewModel(source: try Stub.item(1))
```

（共 6 處，分佈在三個測試中：`載入成功時填入cells與nextOffset` 3 處、`已經到底時loadMore不再發請求` 1 處、`收藏過濾會改變displayCells` 2 處。）

- [ ] **Step 8: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED

- [ ] **Step 9: 在模擬器上確認 cell 會重刷**

沿用 Task 4 Step 4 的安裝與啟動指令。

Expected: 列表每一格從「Loading...」變成寶可夢名稱、縮圖載入、屬性標籤與邊框顏色出現。**這一項是本 Task 的核心驗收**——若 cell 停在 Loading 不動，代表 `@Observable` 的追蹤沒有生效。

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "drop Rx from CellViewModel and PokemonCell

CellViewModel 是 diffable 的 item identifier,== 與 hash 只能看不變的 number,
所以資料載入完成時 snapshot 不會變、cell 不會被重建。原本靠 Rx 的 drive
直接把值推進 label,Rx 拿掉這條線就斷了。

解法是讓 CellViewModel 自己變成 @Observable,由 cell observe 它。可變狀態
必須是 CellViewModel 自己的儲存屬性——留在獨立的 Dependency class 裡
Observation 看不到,所以 Dependency 整個併入。

ErrorTracker 早就沒有呼叫端,HUDTracker 只服務這裡的 Rx 版 transform,一併刪除。"
```

---

### Task 7: 清除最後的 Rx 並移出 Podfile

**Files:**
- Modify: `Pokmon/Feature/UIComponent/EmptyView.swift`
- Modify: `Pokmon/Feature/UIComponent/IndicatorView.swift`
- Modify: `Pokmon/Model/NetworkService/NetworkService.swift`
- Modify: `PokmonTests/Mock/MockService.swift`
- Modify: `Podfile`

**Interfaces:**
- Produces: `NetworkService` 只剩 `func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model`
- Produces: `APIService` 由 `final class` 改為 `actor`，`Endpoint` 標記 `Sendable`

- [ ] **Step 1: 刪除兩個 `Reactive` extension**

`Pokmon/Feature/UIComponent/EmptyView.swift`：刪除開頭的 `import RxSwift` 與 `import RxCocoa`，並刪除檔案末尾整個 `extension Reactive where Base: UIView { ... }` 區塊（`var isEmpty: Binder<Bool>`）。功能已由 Task 3 的 `UIView.setEmpty(_:)` 取代。

`Pokmon/Feature/UIComponent/IndicatorView.swift`：刪除開頭的 `import RxSwift`，並刪除檔案末尾整個 `extension Reactive where Base: UIView { ... }` 區塊（`var indicatorAnimator: Binder<Bool>`）。功能已由 `UIView.setLoading(_:)` 取代。

- [ ] **Step 2: `Endpoint` 標記 `Sendable`**

`actor` 的協定實作需要參數型別是 `Sendable`，否則會報 `non-Sendable parameter type 'T' cannot be sent from caller of protocol requirement 'request' into actor-isolated implementation`。

`Pokmon/Model/NetworkService/Endpoint.swift` 的協定宣告改為：

```swift
protocol Endpoint: Sendable {
    associatedtype Model: Codable & Sendable
```

三個具體 endpoint（`PokemonListEndpont`、`PokemonEndpoint`、`PokemonSpeciesEndpoint`）的儲存屬性都是 `Int` / `String`，會自動取得 `Sendable`，不需修改。三個 response 型別的儲存屬性也全是 Sendable，同樣自動符合。

- [ ] **Step 3: `NetworkService` 刪掉 Rx 版並把 `APIService` 改成 actor**

改寫 `Pokmon/Model/NetworkService/NetworkService.swift` 全檔：

```swift
//
//  NetworkService.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import Foundation

protocol NetworkService: Sendable {
    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model
}

/// 用 actor 把 Alamofire 的 `Session` 關起來。
/// `Session` 的文件說它 thread-safe,但 5.8.1 沒有 Sendable 標註;與其在型別上
/// 掛 `@unchecked Sendable` 自己保證,不如讓編譯器用 actor 隔離幫忙保證。
actor APIService: NetworkService {

    static let share: APIService = .init()

    private let session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        return Session(configuration: configuration, startRequestsImmediately: false)
    }()

    private init() {}

    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let dataRequest = try makeRequest(endpoint)
                dataRequest.responseDecodable(of: T.Model.self) { response in
                    switch response.result {
                    case .success(let model):
                        continuation.resume(returning: model)
                    case .failure(let fail):
                        continuation.resume(throwing: PkError.afError(fail))
                    }
                }
                dataRequest.resume()
            } catch let afError as AFError {
                continuation.resume(throwing: PkError.afError(afError))
            } catch {
                continuation.resume(throwing: PkError.unknown(error))
            }
        }
    }

    private func makeRequest<T: Endpoint>(_ endpoint: T) throws -> DataRequest {
        let parameters = try endpoint.setupParameter()
        var urlString = endpoint.baseURL
        if !endpoint.path.isEmpty {
            urlString += "/\(endpoint.path)"
        }
        guard let url = URL(string: urlString) else {
            throw PkError.urlError(.init(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.httpMethod.rawValue
        request.headers = endpoint.httpHeaders
        request.timeoutInterval = 30

        return session.request(try endpoint.endcoder.encode(request, with: parameters))
    }
}
```

- [ ] **Step 4: `MockService` 去 Rx 並改為 `@MainActor`**

同步的 Rx 需求消失後，`@MainActor` 就不再產生警告，可以拿掉 `@unchecked Sendable`。

改寫 `PokmonTests/Mock/MockService.swift` 全檔：

```swift
//
//  MockService.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
@testable import Pokmon

@MainActor
final class MockService: NetworkService {

    var injectAsyncResponse: Any?
    var injectAsyncError: Error?
    private(set) var requestedPaths: [String] = []

    func request<T>(_ endpoint: T) async throws -> T.Model where T: Pokmon.Endpoint {
        requestedPaths.append(endpoint.path)
        if let injectAsyncError {
            throw injectAsyncError
        }
        guard let model = injectAsyncResponse as? T.Model else {
            throw PkError.badRequest
        }
        return model
    }
}
```

`MockFavoriteUseCase` 與 `MockListUseCase` **不動**，維持 Task 1 給的 `@unchecked Sendable`。原因：`FavoriteUseCase` 的需求全是同步的，`@MainActor` 實作無法滿足 nonisolated 的同步需求；`MockService` 之所以能改，是因為它的需求 `request` 是 `async`，而 async 需求允許由 actor-isolated 的實作滿足。

僅確認兩者的 `import RxSwift` 已在 Task 1 移除。

- [ ] **Step 5: Podfile 移除四個 Rx pod**

`Podfile` 改為：

```ruby
target 'Pokmon' do
  use_frameworks!

  pod 'Alamofire'
  pod 'Kingfisher'

  target 'PokmonTests' do
    inherit! :search_paths
  end

  target 'PokmonUITests' do
  end

end
```

```bash
pod install
```

- [ ] **Step 6: 確認 Rx 已完全消失**

```bash
git grep -in "RxSwift\|RxCocoa\|RxRelay\|RxBlocking\|RxTest\|Swinject\|import Combine\|DisposeBag\|Observable<" -- Pokmon PokmonTests PokmonUITests Podfile
```

Expected: 無任何輸出

```bash
grep -E "RxSwift|Swinject" Podfile.lock
```

Expected: 無任何輸出

- [ ] **Step 7: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "remove RxSwift entirely, Podfile down to two pods

Reactive.Binder 的兩個 extension 換成 UIView 的一般方法,
NetworkService 的 Observable 版刪除。

APIService 改成 actor:Alamofire 的 Session 文件說 thread-safe 但沒有
Sendable 標註,與其掛 @unchecked Sendable 自己保證,不如讓 actor 隔離
幫忙保證。actor 的協定實作要求參數 Sendable,所以 Endpoint 也跟著標了。

Podfile 從 7 個 pod 減到 2 個。"
```

---

### Task 8: 打開 Swift 6 語言模式

前七個 Task 已經把絕大多數併發問題解掉，此處只剩三個修正點。

**Files:**
- Modify: `Pokmon.xcodeproj/project.pbxproj`
- Modify: `Pokmon/Feature/Detail/PokemonDeatilPageViewController.swift`

**Interfaces:**
- Produces: app 與兩個 test target 的 `SWIFT_VERSION = 6.0`；Pods 不受影響

- [ ] **Step 1: 切換語言模式**

```bash
sed -i '' 's/SWIFT_VERSION = 5.0;/SWIFT_VERSION = 6.0;/g' Pokmon.xcodeproj/project.pbxproj
grep -c "SWIFT_VERSION = 6.0" Pokmon.xcodeproj/project.pbxproj
```

Expected: `6`（app、unit test、UI test 各自的 Debug 與 Release）

這 6 處全在 target 層級的 build configuration，專案層級沒有 `SWIFT_VERSION`，Pods 是獨立的 project 各自保留設定。**Pods 停在 Swift 5 正是第三方沒有連鎖爆炸的原因**：跨模組匯入 Swift 5 模組時，編譯器自動套用寬鬆的 Sendable 診斷。

- [ ] **Step 2: 執行建置，記錄錯誤**

Run: BUILD
Expected: 失敗，錯誤應為 `PokemonDeatilPageViewController.swift` 的
`cannot access property 'onFinish' with a non-Sendable type '((PokemonSpeciesResponse?) -> Void)?' from nonisolated deinit`

若出現其他錯誤，逐一處理後再繼續；不要略過。

- [ ] **Step 3: `deinit` 改為 `isolated deinit`**

`Pokmon/Feature/Detail/PokemonDeatilPageViewController.swift` 中：

```swift
    deinit {
        onFinish?(nil)
    }
```

改為：

```swift
    /// nonisolated deinit 碰不到非 Sendable 的 closure。
    /// isolated deinit 讓它在 MainActor 上執行(Swift 6.2 起支援)。
    isolated deinit {
        onFinish?(nil)
    }
```

- [ ] **Step 4: 建置與測試**

Run: BUILD
Expected: BUILD SUCCEEDED

Run: TEST
Expected: TEST SUCCEEDED

- [ ] **Step 5: 確認沒有殘留的併發警告**

```bash
xcodebuild build -workspace Pokmon.xcworkspace -scheme Pokmon \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "warning:.*(Sendable|concurrency|actor|isolated)" \
  | grep -v "/Pods/" | sort -u
```

Expected: 無輸出。若有殘留，逐一修正——不得以 `@unchecked Sendable` 草草掩蓋，除非有明確的 thread-safety 依據並寫在註解裡。

- [ ] **Step 6: 在模擬器上做一次完整回歸**

沿用 Task 4 Step 4 的安裝與啟動指令，逐項確認：

1. 列表載入第一頁，每格從 Loading 變成名稱 + 縮圖 + 屬性標籤
2. 滾到底自動載入下一頁
3. 切換 List / Grid 版型
4. 點某一格進入詳情頁，species 文字載入
5. 點星號，圖示即時切換
6. 返回列表，再次進入同一格，不重新請求 species
7. 收藏過濾按鈕：開啟後只剩已收藏項目，關閉後恢復

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "enable Swift 6 language mode

app 與兩個 test target 切到 SWIFT_VERSION 6.0,Pods 停在 5.0。
Pods 不動正是第三方沒有連鎖爆炸的原因:跨模組匯入 Swift 5 模組時
編譯器自動套用寬鬆的 Sendable 診斷,所以 Alamofire 5.8.1 與
Kingfisher 7.11.0 都不需要 @preconcurrency import。

前七步已經把併發問題解得差不多,這裡只剩 deinit 一處:
nonisolated deinit 碰不到非 Sendable 的 closure,改用 isolated deinit。"
```

---

### Task 9: 撰寫遷移講稿

**Files:**
- Create: `docs/uikit-to-concurrency/README.md`
- Create: `docs/uikit-to-concurrency/01-why-migrate.md`
- Create: `docs/uikit-to-concurrency/02-async-foundation.md`
- Create: `docs/uikit-to-concurrency/03-transform-to-send.md`
- Create: `docs/uikit-to-concurrency/04-disposebag-to-task.md`
- Create: `docs/uikit-to-concurrency/05-navigation-continuation.md`
- Create: `docs/uikit-to-concurrency/06-combine-to-observation.md`
- Create: `docs/uikit-to-concurrency/07-cell-last-mile.md`
- Create: `docs/uikit-to-concurrency/08-drop-di-container.md`
- Create: `docs/uikit-to-concurrency/09-swift6-mode.md`
- Create: `docs/uikit-to-concurrency/10-tests-migration.md`
- Create: `docs/uikit-to-concurrency/11-wrap-up.md`

**Interfaces:**
- Consumes: Task 1–8 的所有 commit hash（以 `git log --oneline` 取得實際值填入）

- [ ] **Step 1: 寫索引頁**

`docs/uikit-to-concurrency/README.md` 需包含：講稿目的、適用對象、專案在遷移前後的數字對照（pod 數 7 → 2、Rx 檔案數 9 → 0、Store 測試覆蓋 0 → 12 個測試）、以及 11 章的連結與各章對應的 commit hash。

- [ ] **Step 2: 寫第 1–5 章（回顧既有 commit）**

這五章講的是 `concurrency` 分支在本計畫之前就完成的工作，內容從既有 commit 的 diff 取材：

| 章 | 檔案 | 取材 commit | 必須包含的重點 |
|---|---|---|---|
| 1 | `01-why-migrate.md` | — | Rx 的三個成本：學習曲線、除錯時的堆疊深度、與語言演進脫節。用本專案的實際數字說明 |
| 2 | `02-async-foundation.md` | `8d44f10` | 先讓 `async` 版 `request` 與 Rx 版並存，是讓遷移可以分批進行的關鍵；`withCheckedThrowingContinuation` 怎麼包 callback API |
| 3 | `03-transform-to-send.md` | `d63c3d8` `c503004` | `transform(Input) -> Output` 換成 `send(Action)` + `State`；為什麼單向資料流讓狀態變得可測 |
| 4 | `04-disposebag-to-task.md` | `e65bc0a` | `DisposeBag` 換 `Task` handle；`Task.isCancelled` 的陷阱——取消時丟的不一定是 `CancellationError`，要判旗標不要比對型別；`defer` 裡為什麼要判 `!Task.isCancelled` 才清 `isLoading` |
| 5 | `05-navigation-continuation.md` | `d63c3d8`（協定改 `async`）`c503004`（接上 continuation） | delegate / closure 回呼換成 `withCheckedContinuation`；continuation 必須且只能 resume 一次，`onFinish` 如何保證 |

每章格式：先貼遷移前的程式碼，再貼遷移後，然後說明「為什麼這一步要排在這個位置」。

- [ ] **Step 3: 寫第 6–8 章（本次的架構改動）**

| 章 | 檔案 | 對應 Task | 必須包含的重點 |
|---|---|---|---|
| 6 | `06-combine-to-observation.md` | Task 3、4、5 | `withObservationTracking` 只通知一次，所以要自我重新掛載；`onChange` 是 willSet 語義，得丟進 `Task` 才讀得到新值；`observe` 為何必須掛 `UIResponder` 而非 `NSObject`；**保留單一 `State` struct 的代價**——所有 closure 一起重跑，逐一檢查冪等性，只有 `presentAlert` 需要擋 |
| 7 | `07-cell-last-mile.md` | Task 6 | diffable 的 item identifier 是可變 class 會發生什麼事：`==`/`hash` 只能看不變欄位 → snapshot 不變 → cell 不重建 → Rx 的 `drive` 一拿掉畫面就停在 Loading。解法是讓 view model 自己 `@Observable`。**必須誠實寫出這個型別身兼三職（identifier、發請求的 view model、跨頁資料包）的張力，以及「拆成 ID + 值型別、讀取收進 Store」是下一步可以走的路** |
| 8 | `08-drop-di-container.md` | Task 1 | Swinject 換 `@TaskLocal`；為什麼要在 `Dependency.init` 快照而不是每次存取才讀；`Task.detached` 不繼承 TaskLocal 的坑；`FavoriteUseCase` 為何選 `OSAllocatedUnfairLock` 而不是 actor（改 async 會污染 Store 的同步流程） |

- [ ] **Step 4: 寫第 9–11 章**

| 章 | 檔案 | 對應 Task | 必須包含的重點 |
|---|---|---|---|
| 9 | `09-swift6-mode.md` | Task 7、8 | **本場的重頭戲**。逐一解讀七個錯誤及其解法：三個 non-Sendable 單例、`NetworkService` 要 `Sendable`、`Endpoint.Model` 要 `Sendable`、delegate 協定要 `@MainActor`、`CellViewModel` 不是 Sendable、`isolated deinit`。以及**為什麼 Alamofire / Kingfisher 沒有連鎖爆炸**——Pods 停在 Swift 5，跨模組匯入自動套用寬鬆診斷，所以升級語言模式不必等第三方先升 |
| 10 | `10-tests-migration.md` | Task 2、6 | RxTest 的 `TestScheduler` 虛擬時間換成 `await task.value`；為什麼選 Swift Testing（`@Test func` 本身可 async，不必繞 `XCTestExpectation`）；把 task handle 開成 `private(set)` 是刻意留的測試接縫 |
| 11 | `11-wrap-up.md` | 全部 | 數字對照；建議團隊採用的遷移順序（先立 async 地基 → 換狀態容器 → 換綁定層 → 拔 DI → 開語言模式），以及為什麼這個順序能讓每一步都保持可編譯可測試；預期會被問到的問題 |

- [ ] **Step 5: 填入實際的 commit hash**

```bash
git log --oneline main..concurrency
```

把輸出的 hash 對應填進 README 與各章的「對應 commit」欄位。

- [ ] **Step 6: 檢查講稿內的程式碼片段與實際程式碼一致**

逐章比對每個「遷移後」的程式碼片段，確認與 repo 中的最終版本相符。這是講稿最容易腐爛的地方。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "add UIKit to Swift Concurrency migration talk

11 章對應 11 個 commit,團隊可以邊看 git log 邊讀。
前五章回顧分支上既有的工作,後六章是這次的改動。

第 9 章是重頭戲:七個 Swift 6 錯誤逐一解讀,以及為什麼第三方沒有
連鎖爆炸。第 7 章誠實寫出 CellViewModel 身兼三職的張力,以及下一步
可以怎麼走。"
```

---

## Self-Review

**Spec coverage**

| Spec 章節 | 對應 Task |
|---|---|
| §5.1 相依瘦身（Podfile 7 → 2） | Task 1 Step 9（Swinject）、Task 7 Step 5（四個 Rx pod） |
| §5.2 併發基線（`SWIFT_VERSION` 6.0） | Task 8 Step 1 |
| §5.3 相依注入（`Dependencies.swift`、Sendable 調整） | Task 1；`Endpoint`/`APIService` 延後到 Task 7（Rx 版 `request` 需先移除） |
| §5.4 綁定層（`observe`、`@Observable`、`Info.isFavorite`） | Task 3、4、5 |
| §5.5 Rx 逐檔清除 | Task 6（`CellViewModel`、`PokemonCell`、兩個 tracker）、Task 7（兩個 Binder extension、`NetworkService`）、Task 5（`PokemonDetailInfoCell`、delegate `@MainActor`）、Task 8（`isolated deinit`） |
| §5.6 測試 | Task 1（mock、`UserDefaultStoreTests`）、Task 2（兩個 Store 測試、Stub）、Task 6（`CellViewModelTests`） |
| §6 講稿 11 章 | Task 9 |
| §7 驗證 | 每個 Task 的最後兩步；Task 7 Step 6 的 grep、Task 8 Step 6 的完整回歸 |

Spec §5.3 表格把 `Endpoint`、`APIService` 的 Sendable 調整列在 DI 步驟；本計畫把它們延後到 Task 7，因為 `APIService` 改 actor 必須等 Rx 版同步 `request` 移除。Task 1 Step 4 已寫明此順序與理由。

**Placeholder scan**：無 TBD / TODO；每個程式碼步驟都附完整可編譯的程式碼；Task 9 的章節以表格明確列出各章必須包含的重點，而非「寫一章關於 X」。

**Type consistency**

- `Dependencies.network` / `.favorite` / `.list` — Task 1 定義，Task 6 的 `CellViewModel.init` 預設值引用
- `UserDefaultStore.shared` — Task 1 定義並在同 Task 的 `Dependencies` 引用
- `MockService.requestedPaths` — Task 1 Step 7 加入，Task 2 與 Task 6 的測試使用
- `store.loadTask` / `store.detailTask` — Task 2 Step 2 開放，Task 2、6 的測試 `await`
- `CellViewModel.init(source:service:sepies:pokemon:)` — Task 6 Step 1 定義；Task 6 Step 7 同步更新 Task 2 寫下的呼叫端（Task 2 當時用的是 `init(dependency:)`）
- `UIView.setLoading(_:)` / `setEmpty(_:)` — Task 3 定義，Task 4、5 使用；Task 7 才刪掉被取代的 Rx Binder
- `Info.isFavorite: @MainActor () -> Bool` — Task 5 Step 1 定義，同 Task Step 2、3 使用

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-31-rxswift-to-swift-concurrency.md`.
