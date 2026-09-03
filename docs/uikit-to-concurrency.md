# UIKit 裡的 Swift Concurrency，以及往 SwiftUI 的路

團隊內部分享，15–20 分鐘。

這份不是 API 教學，是一次真實遷移的紀錄：一個 UIKit + RxSwift 的 App 怎麼在
**每一步都保持可編譯、可測試**的前提下換成 Swift Concurrency + Observation，
以及做完之後離 SwiftUI 還有多遠。

程式碼全部來自這個 repo，遷移前的基準點是 `72cbcf4`。

## 15 分鐘怎麼講

這份文件本身是**完整版**，全部講完約 35–45 分鐘。15–20 分鐘的場次建議只講下面
五段，其餘直接說「細節在文件裡」：

| 講 | 段落 | 分鐘 |
|---|---|---|
| ✅ | 數字（下一節） | 1 |
| ✅ | §2 狀態容器 —— `transform` 換 `send(Action)` + `State`，含 `Task` 的兩個陷阱 | 4 |
| ✅ | §3 綁定層 —— 只講**捕捉契約**那一條，其餘帶過 | 3 |
| ⭐ | §5 兩個案例 —— **全場重點，不要壓縮** | 6 |
| ✅ | §6 SwiftUI 對照表 + spike | 4 |
| ➖ | §1 地基、§4 依賴與導航、Swift 6 —— 留給自行閱讀 | — |

如果只能留一句話帶走，是 §5 的結論：**「行為不變」和「行為改變」都是需要證明的
主張，不是預設。**

## 數字

| | 遷移前 | 現在 |
|---|---|---|
| 相依管理 | CocoaPods，7 個 pod | SPM，2 個 package |
| `import RxSwift` / `RxCocoa` 的檔案 | 20 | 0 |
| Swift 語言模式 | 5 | 6（strict concurrency） |
| 測試 | 5 個 test method | 29 個測試 / 6 個 suite |

---

# Part 1 — UIKit 裡怎麼用 Swift Concurrency

## 1. 地基：先讓新舊並存

最容易失敗的做法是「開一個分支把 Rx 全部拔掉」。實際可行的第一步是**讓
`async` 版的 service 跟 Rx 版並存**，這樣後面每一個畫面都可以獨立搬，隨時可以停。

```swift
// 遷移前：回傳 Observable
protocol NetworkService {
    func request<T: Endpoint>(_ endpoint: T) -> Observable<T.Model>
}

func request<T: Endpoint>(_ endpoint: T) -> Observable<T.Model> {
    .create { subscriber in
        // ...組 request...
        let dataRequest = self.session.request(newRequest)
            .responseDecodable(of: T.Model.self) { response in
                switch response.result {
                case .success(let model):
                    subscriber.onNext(model)
                    subscriber.onCompleted()
                case .failure(let fail):
                    subscriber.onError(fail)
                }
            }
        dataRequest.resume()
        return Disposables.create {
            dataRequest.cancel()
        }
    }
}
```

`Observable.create` 在做的事情，`withCheckedThrowingContinuation` 也做得到，而且
少了「訂閱 / disposable」這層概念：

```swift
// 遷移中：用 continuation 包住 callback API
func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model {
    try await withCheckedThrowingContinuation { continuation in
        do {
            let dataRequest = try makeRequest(endpoint)
            dataRequest.responseDecodable(of: T.Model.self) { response in
                switch response.result {
                case .success(let model): continuation.resume(returning: model)
                case .failure(let fail):  continuation.resume(throwing: PkError.afError(fail))
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
```

**continuation 的規則只有一條：必須 resume，而且只能 resume 一次。** 上面每一條
分支都恰好呼叫一次，這是寫這種橋接時唯一要盯的事。

> 後話：這段 continuation 現在也不見了。Alamofire 5.10 之後有原生 async API，
> 整個方法縮成 `try await makeRequest(endpoint).serializingDecodable(T.Model.self).value`。
> 但那是最後一步，不是第一步——第一步的價值在於**讓兩套並存**。

## 2. 狀態容器：`transform(Input) -> Output` 換成 `send(Action)` + `State`

Rx 版的 ViewModel 是這個形狀：

```swift
struct Input {
    let changeLayout: Driver<Void>
    let clickFavorite: Driver<Void>
    let bindView: Driver<Void>
    let viewWillAppear: Driver<Void>
    let loadMore: Driver<Void>
    let clickCell: Driver<CellViewModel>
}
struct Output {
    let isListOrGrid: Driver<Bool>
    let isFavorite: Driver<Bool>
    let isLoading: Driver<Bool>
    let isEmpty: Driver<Bool>
    let list: Driver<[CellViewModel]>
    let configuration: Driver<Void>
}
func transform(_ input: Input) -> Output {
    var isListOrGrid = true          // 狀態散落在 transform 的區域變數裡
    var isFavorite = true
    let listsRelay = BehaviorRelay<[CellViewModel]>(value: [])
    // ...六條 Driver 各自組裝...
}
```

問題不在 Rx，在**狀態沒有名字**。`isListOrGrid` 是 `transform` 裡的區域變數，
測試唯一能碰到它的方式是推事件進 `Input` 再從 `Output` 觀察 —— 這正是需要
`RxTest` 的 `TestScheduler` 跟虛擬時間的原因。

換成一個 `@Observable` 的 Store 之後，狀態變成一個可以直接讀的 struct：

```swift
@Observable
@MainActor
final class PokemonListStore {

    private(set) var viewState: State = .init()

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            syncFavorites()
            load()

        case .tapChangeLayout:
            viewState.isListLayout.toggle()

        case .tapFavorite:
            viewState.isFavoriteFilterOn.toggle()
            syncFavorites()

        case .tapCell(let cell):
            showDetail(cell)

        case .dismissAlert:
            viewState.alert = nil

        // ...viewWillAppear / loadMore 略
        }
    }

    struct State: Equatable {
        var isListLayout: Bool = true
        var isFavoriteFilterOn: Bool = false
        var isLoading: Bool = false
        var alert: AlertState?
        var cells: [CellViewModel] = []
        var favoriteNumbers: Set<Int> = []
        /// nil 代表已經到底
        var nextOffset: Int? = 0

        var displayCells: [CellViewModel] {
            isFavoriteFilterOn
                ? cells.filter { favoriteNumbers.contains($0.number) }
                : cells
        }

        var isEmpty: Bool { displayCells.isEmpty }
        var hasNextPage: Bool { nextOffset != nil }
    }
}
```

測試因此變成三行，不需要虛擬時間：

```swift
store.send(.onAppear)
await store.loadTask?.value
#expect(store.viewState.cells.map(\.number) == [1, 2, 3])
```

### `DisposeBag` 換成 `Task` handle，以及兩個陷阱

```swift
private func load() {
    loadTask?.cancel()
    loadTask = Task { [weak self] in
        guard let self else { return }
        self.viewState.isLoading = true
        // 被取代時不清掉，否則新舊兩個 Task 的恢復順序會讓 loading 閃掉
        defer { if !Task.isCancelled { self.viewState.isLoading = false } }
        do {
            let response = try await self.api.list(offset)
            guard !Task.isCancelled else { return }
            // ...
        } catch {
            // 取消時丟的不一定是 CancellationError，判旗標不要比對型別
            guard !Task.isCancelled else { return }
            self.viewState.alert = .init(error: error)
        }
    }
}
```

兩個踩過的坑，都寫在註解裡了：

1. **取消時丟出來的不一定是 `CancellationError`。** URLSession 丟的是自己的錯誤，
   所以判斷要用 `Task.isCancelled` 這個旗標，不要 `catch is CancellationError`。
   否則使用者滑很快的時候會看到一堆假的錯誤 alert。
2. **`defer` 裡要判旗標才清 `isLoading`。** 被新的 Task 取代時如果照樣清，
   新舊兩個 Task 的恢復順序會讓 loading indicator 閃一下。

`loadTask` 開成 `private(set)` 是**刻意留的測試接縫** —— 測試靠
`await store.loadTask?.value` 等非同步流程結束，這比 sleep 或 expectation 穩定。

## 3. 綁定層：`drive` / `sink` 換成 `observe`

Rx 版把值推進 UI：

```swift
output.name.drive(nameLabel.rx.text).disposed(by: disposeBag)
output.number.drive(numberLabel.rx.text).disposed(by: disposeBag)
```

Observation 沒有內建的 UIKit 綁定，所以自己寫一個 `observe`。它只有十行，但
**每一行都是踩出來的**：

```swift
@MainActor
extension UIResponder {
    @discardableResult
    func observe(_ apply: @escaping @MainActor () -> Void) -> ObservationToken {
        let token = ObservationToken()
        observe(token: token, apply)
        return token
    }

    private func observe(token: ObservationToken, _ apply: @escaping @MainActor () -> Void) {
        guard !token.isCancelled else { return }
        withObservationTracking(apply) {
            Task { @MainActor [weak self] in
                guard let self, !token.isCancelled else { return }
                self.observe(token: token, apply)   // 自己把自己重新掛回去
            }
        }
    }
}
```

三件必須知道的事：

1. **`withObservationTracking` 只通知一次。** 所以 `onChange` 裡要重新掛載，
   否則畫面只會更新第一次。
2. **`onChange` 是 willSet 語義**，在值真正寫入**之前**觸發。所以不能在
   `onChange` 裡直接讀新值，得丟進 `Task` 等這一輪寫完，重新掛載時 `apply`
   讀到的才是新值。
3. **捕捉契約：`apply` 不可以強捕捉被觀察的物件。**

第 3 點是最貴的一課：

```swift
// ✗ 錯：apply 強捕捉 viewModel
observe { [weak self] in self?.nameLabel.text = viewModel.displayName }

// ✓ 對：只捕捉弱的 self，物件從 self 身上取
observe { [weak self] in
    guard let self, let viewModel = self.viewModel else { return }
    self.nameLabel.text = viewModel.displayName
}
```

`@Observable` 合成的 registrar 是**被觀察物件自己的儲存屬性**，而 `apply` 會被
註冊到它上面。強捕捉就形成 `viewModel → registrar → onChange → apply → viewModel`
的環，物件自己吊住自己，跟觀察者的生命週期無關。

而且 **`cancel()` 擋不掉這個環**：它只阻止*下一次*重新掛載，無法註銷已經註冊、
尚未觸發的那一次，Observation 也沒有提供主動註銷的 API。該註冊要等被追蹤的屬性
再變動一次才會釋放 —— 若物件已經沒人會再改它，就永遠不會釋放。

### 代價：單一 `State` struct 讓所有 closure 一起重跑

`viewState` 是單一屬性，任何欄位變動都會讓**所有** `observe` closure 重跑。
這在絕大多數情況沒差，因為那些動作都是冪等的（設 text、設 image、apply snapshot）。
只有 present alert 不冪等，所以那一條要自己防重複 —— 這件事直接引出下一節。

## 4. 依賴與導航

### Swinject 換成 `@TaskLocal` + client

```swift
// 遷移前
final class InjectObject {
    static let shared: InjectObject = .init()
    func configuration() {
        self.container.register(FavoriteUseCase.self) { _ in
            return UserDefaultWrapper.share
        }.inObjectScope(.container)
        self.container.register(NetworkService.self) { _ in
            return APIService.share
        }.inObjectScope(.container)
        // ...
    }
}
```

```swift
// 現在：沒有容器，也沒有 protocol
enum Dependencies {
    @TaskLocal static var api: PokemonAPIClient = .live
    @TaskLocal static var favorites: FavoritesClient = .live
}

struct PokemonAPIClient: Sendable {
    var list: @Sendable (_ offset: Int) async throws -> PokemonListResponse
    var pokemon: @Sendable (_ id: Int) async throws -> PokmonResponse
    var species: @Sendable (_ id: Int) async throws -> PokemonSpeciesResponse
}
```

「依賴」從 **protocol + 實作 + mock 三個型別**，變成 **一個 struct of closures**。
測試不再需要 mock class：

```swift
private func makeAPI(
    list: @escaping @Sendable (Int) async throws -> PokemonListResponse = { _ in
        throw PkError.badRequest      // 沒指定的給明確拋錯，誤呼叫時測試會紅而不是靜默通過
    }
) -> PokemonAPIClient {
    .init(list: list, pokemon: { _ in throw PkError.badRequest }, species: { _ in throw PkError.badRequest })
}
```

**`@TaskLocal` 有一個時序陷阱**：它的值是在 `Task` 建立當下捕捉的。若在方法內
（尤其 `Task { }` 內）才讀，就會變成「Task 建立時機決定讀到誰」，在
`withValue { }` 外建立的 Task 會讀到 live 實作而打到真實網路。

所以規則是：**只能在 init 的預設參數位置讀，讀到就存成 `let`。**

```swift
init(
    navigator: PokemonListNavigator,
    api: PokemonAPIClient = Dependencies.api,          // 唯一的快照點
    favorites: FavoritesClient = Dependencies.favorites
) { ... }
```

同一個原則在 Store 內部也要守 —— 把 cell 建起來時，`api` 必須顯式傳下去：

```swift
self.viewState.cells += response.results.map {
    CellViewModel(source: $0, api: self.api)   // 靠 CellViewModel 的預設值會讀到 live
}
```

### 導航也是一個 client

導航原本是兩個 protocol 加一個 class，`Coordinator` 持有 `weak var viewController`，
必須在 store 建好之後才回填 —— 因為 store → coordinator → VC → store 是個環。

現在它是 client，`withCheckedContinuation` 把「push 進去，等使用者關掉再回傳」
包成一個 `async` 呼叫：

```swift
@MainActor
struct PokemonListNavigator {
    var showDetail: @MainActor (any PokemonShareData) async -> PokemonSpeciesResponse?
}

static func live(navigation: UINavigationController) -> Self {
    .init(showDetail: { [weak navigation] model in
        guard let pokemon = try? model.getPokemon() else { return nil }
        let detailViewController = PokemonDeatilPageViewController(
            store: PokemonDetailStore(pokemon: pokemon, species: model.spiecs)
        )
        return await withCheckedContinuation { continuation in
            detailViewController.onFinish = { continuation.resume(returning: $0) }
            navigation?.pushViewController(detailViewController, animated: true)
        }
    })
}
```

這裡有個容易漏的細節：如果 `navigation` 已經是 nil，push 不會發生，
`detailViewController` 隨即釋放 —— continuation 由它的 `isolated deinit`
呼叫 `onFinish(nil)` 收掉。少了那個 deinit，這裡的 `await` 會永遠掛住。

**這個 client 刻意不是 `Sendable`，所以進不了 `Dependencies`。** navigation
controller 是 per-scene 的，process 啟動當下不存在；任何讓它變成零參數 `.live`
的寫法，背後都得養一個全域可變的「當前 navigation」。它改由 composition root 傳入：

```swift
enum PokemonListScene {
    @MainActor
    static func make() -> UIViewController {
        let navigation = UINavigationController()
        let store = PokemonListStore(navigator: .live(navigation: navigation))
        navigation.viewControllers = [PokemonListViewController(store: store)]
        return navigation
    }
}
```

### 打開 Swift 6：第三方沒有連鎖爆炸

開語言模式時最大的疑慮是「第三方還沒準備好怎麼辦」。答案是**不必等**：
跨模組匯入時，來自 Swift 5 模組的型別會自動套用寬鬆診斷。當時 Alamofire
與 Kingfisher 都還沒標 `Sendable`，語言模式照樣打得開。

要處理的是自己的程式碼，主要是幾個單例與隔離標註。例如 `Session` 當時沒有
`Sendable` 標註，就用 actor 把它關起來：

```swift
// 當時：讓編譯器用 actor 隔離幫忙保證
actor APIService { private let session: Alamofire.Session ... }
```

而升級套件之後，這層包裝就可以拆掉了 —— Alamofire 5.10 起 `Session` 自己就是
`@unchecked Sendable`，保證由函式庫作者給，那才是它該待的位置：

```swift
final class APIService: Sendable {
    private let session: Alamofire.Session = .init(configuration: URLSessionConfiguration.default)

    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model {
        do {
            return try await makeRequest(endpoint).serializingDecodable(T.Model.self).value
        } catch let afError as AFError {
            throw PkError.afError(afError)
        } catch {
            throw PkError.unknown(error)
        }
    }
}
```

## 5. ⭐ 兩個案例：行為有沒有變，都要證明

這節是整場的重點。兩個 bug，方向剛好相反，**共同點是測試都全過**。

### 案例一：遷移「悄悄改變」了行為 —— alert 去重

中途的 Combine 寫法：

```swift
state
    .compactMap(\.alert)
    .removeDuplicates()
    .sink { [weak self] alert in
        self?.presentAlert(alert) { [weak self] in self?.store.send(.dismissAlert) }
    }
    .store(in: &cancellables)
```

換成 Observation 之後：

```swift
observe { [weak self] in
    guard let self else { return }
    guard let alert = self.store.viewState.alert else {
        self.presentedAlert = nil       // 變回 nil 時重設
        return
    }
    guard self.presentedAlert != alert else { return }
    self.presentedAlert = alert
    self.presentAlert(alert) { [weak self] in self?.store.send(.dismissAlert) }
}
```

看起來是同一件事，其實不是。`compactMap` 先把 `nil` 濾掉，所以
`removeDuplicates` 是作用在**非 nil 的子串流**上 —— 中間那個 `nil` 對它是隱形的，
它看到的是 `[A, A]`，於是把第二個吃掉。新寫法的 `presentedAlert` 在 `alert`
變回 `nil` 時會重設，所以第二個相同的 alert 會正常彈出。

而這條路徑在詳情頁是**真實可達**的，因為 `dismissAlert` 會觸發重試：

```swift
case .dismissAlert:
    viewState.alert = nil
    load()              // ← 按 OK 就重試
```

「載入失敗 → 按 OK → 重試又失敗 → 相同的錯誤」會走到。**舊寫法下使用者按了 OK
之後畫面毫無反應** —— 那是 Combine 運算子語意造成的靜默失敗，新寫法反而修好了。

沒有任何測試抓到這個差異（8 個特徵測試全部照樣通過）。是 code review 時逐行推導
運算子語意才發現的。

### 案例二：遷移「悄悄保留」了 bug —— cell 重用殘留

`prepareForReuse` 只清了「`observe` closure 一定會覆寫」的欄位。但其中兩個
closure 會 early return：

```swift
observe { [weak self] in
    guard let self, let viewModel = self.viewModel else { return }
    let types = viewModel.types
    guard !types.isEmpty else { return }        // ← 尚未載入時直接跳出
    self.cornerView.layer.borderColor = types.first?.color.cgColor
    self.typesStackView.setTypes(types)
    self.cornerView.gradientLayer.colors = [...]
}
```

於是上一隻寶可夢的屬性標籤、邊框色與漸層會活到下一格，直到新資料載入為止。

**值得注意的是：這個 bug 不是遷移造成的。** Rx 版一模一樣：

```swift
// 遷移前
override func prepareForReuse() {
    disposeBag = .init()
    thumbNailImageView.kf.cancelDownloadTask()
    thumbNailImageView.image = .placeHolder     // 同樣沒清 stack / borderColor
}
```

機制不同但結果相同：Rx 版的 `types` 是從 `pokemon` 導出的 Driver，**載入完成前
根本不發射**，所以也沒有東西去清舊值。整個綁定層被完整重寫過一次，這個 bug
毫髮無傷地穿了過去 —— 因為重寫忠實複製了舊行為，包括錯的那部分。

同一個 cell 還有另外兩個一起搬過來的缺陷：

```swift
// rotate() 只在 init 呼叫一次，但每次圖片載入完成都 stopRotate
// → cell 第一次載完圖之後就再也不轉了
completionHandler: { result in
    image.stopRotate()
    switch result {
    case .failure: image.image = .errorImage   // 取消也算 failure
    default: break
    }
}
```

第二個特別陰險：Kingfisher 在**取消**（來自 `prepareForReuse` 的
`cancelDownloadTask`）與**已不是當前請求**（舊 binding 的結果在 cell 重新綁定後
才回來）兩種情況都會呼叫 completion handler，而且連成功的過期請求也包成 failure。
所以錯誤圖會蓋到下一格上。修法是先濾掉：

```swift
if case .failure(let error) = result,
   error.isTaskCancelled || error.isNotCurrentTask {
    return
}
```

### 這兩個案例合起來的結論

| | 遷移做了什麼 | 誰抓到的 |
|---|---|---|
| alert 去重 | 悄悄**改變**了行為（意外修好） | code review 推導運算子語意 |
| cell 重用 | 悄悄**保留**了 bug（忠實搬運） | 為 reuse 補測試才紅 |

**「行為不變」和「行為改變」都是需要證明的主張，不是預設。** 特徵測試只保護你
「想到要測」的行為 —— 29 個測試在補上那三個 cell 測試之前，一個都沒紅。

---

# Part 2 — 怎麼慢慢往 SwiftUI 走

## 6. 現在離 SwiftUI 有多遠

前面每一步都是為了離開 Rx，但副作用是**架構被挪到了一個離 SwiftUI 很近的位置**：

| 現在（UIKit） | SwiftUI 的對應 | 要改嗎 |
|---|---|---|
| `@Observable @MainActor` Store + `State` + `send(Action)` | 一模一樣 | **不用改** |
| `observe { }`（自己重掛 `withObservationTracking`） | `body` 自動做 | 整層刪掉 |
| `CellViewModel: @Observable` | row 的 model | **不用改** |
| `AlertState` | `.alert(isPresented:presenting:)` | 不用改 |
| `Dependencies` 的 `@TaskLocal` | 可續用，或換 `@Environment` | 不用改 |
| `PokemonListNavigator` client | `NavigationStack` 的 path | **換一個 `.live`** |
| diffable data source + cell 重用 | `List` / `ForEach` | 整套刪掉 |

repo 裡有一個可跑的 spike（`Pokmon/Feature/List/SwiftUI/`，`#Preview` driven），
證明第一列：**`PokemonListStore` 一行都沒有改。**

```swift
struct PokemonListScreen: View {

    @State private var store: PokemonListStore

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pokemon List (SwiftUI)")
                .toolbar { toolbar }
                .overlay { if store.viewState.isLoading { ProgressView() } }
                .alert(
                    store.viewState.alert?.title ?? "",
                    isPresented: alertBinding,
                    presenting: store.viewState.alert
                ) { _ in
                    Button("OK", role: .cancel) { }
                } message: { alert in
                    Text(alert.message)
                }
        }
        .task { store.send(.onAppear) }
    }
}
```

`PokemonListViewController` 在 `bindStore()` 裡手寫**六個** `observe` closure
（版型、收藏鈕圖示、loading、empty、cells、alert）；上面的 `body` 一個都不需要。
`observe` 那十行程式碼在模擬的，正是 `body` 免費提供的東西。

### 兩件不能直接搬的事

**一、導航。** `.live` 推的是 `UIViewController`，這是唯一真的要重寫的部分。
更根本的是它的形狀：`showDetail` 是「await 到詳情頁關閉才回傳」的 continuation
模型，那是 UIKit-ism；SwiftUI 裡更自然的做法是詳情頁透過共享狀態寫回，而不是
讓呼叫端 await 一個回傳值。

好消息是**要改的位置只有一個**，因為它已經是 client 而不是 protocol：

```swift
// preview 換一個實作就好，真的要遷移時換的也是同一個位置
static var navigator: PokemonListNavigator {
    .init(showDetail: { _ in nil })
}
```

**二、`CellViewModel` 身兼三職。** 它同時是 diffable 的 item identifier、
發請求的 view model、跨頁面的資料包。`==` / `hash` 只能看不變的 `number`，
否則 snapshot 一變 cell 就重建。到了 SwiftUI 這個約束消失了，但那三個職責還在
同一個型別上。下一步可以走的路是**拆成 ID + 值型別，讀取收進 Store**。

### 順帶一提：一整類 bug 直接消失

Part 1 案例二那三個缺陷（屬性殘留、轉圈停掉、錯誤圖蓋到下一格）**在 SwiftUI
結構上不可能發生** —— 沒有被重用的 view 實例，就沒有要清的殘留狀態，也沒有
`prepareForReuse` 這個必須跟 `bindView` 保持對稱的鉤子。

這不是說 SwiftUI 沒有坑，而是說：這三個 bug 全部來自「手動管理可重用 view 的
生命週期」，而那正是 SwiftUI 幫你拿掉的東西。

## 建議的推進順序

跟 Part 1 一樣，重點是**每一步都要能停**：

1. **先立 async 地基** — 新舊 service 並存，之後每個畫面可以獨立搬
2. **換狀態容器** — `send(Action)` + `State`，這步做完就有可測的狀態
3. **換綁定層** — `observe`，這步做完 Rx 可以移除
4. **拔 DI 容器** — protocol + mock 換成 client，測試大幅簡化
5. **打開 Swift 6** — 不必等第三方
6. **一次一屏換 SwiftUI** — Store 不動，只換 view 層；先挑沒有複雜導航的畫面

前五步這個專案都做完了。第六步目前只有一個 spike。

## 可能會被問到的

**Q: 為什麼不直接整包重寫成 SwiftUI？**
每一步都保持可編譯可測試，代表隨時可以停在任何一步交付。整包重寫沒有這個性質。
而且前五步的價值不依賴第六步 —— 就算永遠不換 SwiftUI，Store 可測、依賴可注入、
Swift 6 打開，這些都已經拿到了。

**Q: `observe` 是自己刻的，維護成本呢？**
十行，但那十行踩了三個坑（只通知一次、willSet 語義、捕捉契約）。它是過渡期的
產物 —— 換到 SwiftUI 之後整層刪掉。如果團隊短期內不打算碰 SwiftUI，那這十行
要當成正式基礎設施看待，有測試（`ObserveTests`）。

**Q: struct of closures 比 protocol 好在哪？**
測試不用寫 mock class，未指定的 closure 可以直接給「拋錯」實作，誤呼叫時測試
會紅而不是靜默通過。代價是失去了 protocol 的名字與編譯期的完整性檢查
（少實作一個方法不會有錯誤，因為那是 stored property）。

**Q: 遷移過程中有沒有真的壞掉過？**
有兩個行為差異，都不是測試抓到的（見案例一、二）。這是這場分享最想留下的一句：
**特徵測試只保護你想到要測的行為。**
