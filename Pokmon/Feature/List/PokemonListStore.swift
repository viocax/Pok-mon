//
//  PokemonListStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//
//  Spike:把 PokemonListViewModel 的 Input/Output/Driver 換成
//  `send(Action)` + `@Published State` + Swift Concurrency。
//  行為對齊舊的 PokemonListViewModel,舊檔案完全沒動,兩邊可以並存比較。
//

import Combine
import Foundation

@MainActor
final class PokemonListStore {

    // MARK: - Properties

    /// 唯一對外的狀態出口。所有 UI 都從這裡 scope 出去,不再有六條各自獨立的 Driver。
    @Published private(set) var viewState: State = .init()

    private let dependency: Dependency
    private let tasks: TaskStore<TaskKey> = .init()

    private enum TaskKey {
        case load
        case detail
    }

    // MARK: - Life cycle

    init(dependency: Dependency) {
        self.dependency = dependency
    }

    // MARK: - Input

    /// 唯一的入口。沒有回傳值 — `viewState` 是這個 store 唯一的對外產出。
    func send(_ action: Action) {
        switch action {
        case .onAppear:
            syncFavorites()
            load()

        case .viewWillAppear:
            // 從 Detail 頁回來收藏可能變了,重新同步一次
            syncFavorites()

        case .tapChangeLayout:
            viewState.isListLayout.toggle()

        case .tapFavorite:
            viewState.isFavoriteFilterOn.toggle()
            syncFavorites()

        case .loadMore:
            load()

        case .tapCell(let cell):
            showDetail(cell)

        case .dismissAlert:
            viewState.alert = nil
        }
    }

    // MARK: - private

    private func load() {
        guard let offset = viewState.nextOffset else { return }

        tasks.latest(.load) { [weak self] in
            guard let self else { return }

            self.viewState.isLoading = true
            // trackActivity 的等價物。被新請求取代時不要清掉 loading,
            // 否則新舊兩個 Task 在 MainActor 上的恢復順序會讓 loading 閃掉。
            defer { if !Task.isCancelled { self.viewState.isLoading = false } }

            do {
                let response: PokemonListResponse = try await self.dependency.service
                    .request(PokemonListEndpont(offset: offset))
                // 取消是協作式的,await 回來不會自己中斷。
                // 這裡要檢查是因為「請求跑完了但這個 Task 已被新的取代」,
                // 不檢查就會把過期的結果併進 state。
                guard !Task.isCancelled else { return }

                self.viewState.nextOffset = response.offset
                self.viewState.cells += self.dependency.list.listConvertCell(response.results)
                self.syncFavorites()
            } catch {
                // 取消時 await 丟出來的不一定是 CancellationError —
                // Alamofire 丟 AFError.explicitlyCancelled、URLSession 丟 URLError.cancelled。
                // 所以判斷旗標,不要比對錯誤型別。
                guard !Task.isCancelled else { return }

                // trackError 的等價物,錯誤直接寫進 state
                self.viewState.alert = .init(error: error)
            }
        }
    }

    private func showDetail(_ cell: CellViewModel) {
        tasks.latest(.detail) { [weak self] in
            guard let self else { return }
            // 這裡是寫回 cell 自己的 model,不影響清單畫面,所以不動 viewState
            if let species = await self.dependency.coordinator.showDetailPage(model: cell) {
                cell.updateDetailPage(response: species)
            }
        }
    }

    /// 把「哪些被收藏了」同步進 state,過濾本身交給 `State.displayCells` 這個純函式
    private func syncFavorites() {
        viewState.favoriteNumbers = Set(
            viewState.cells
                .map(\.number)
                .filter { dependency.favorite.isContain("\($0)") }
        )
    }
}

// MARK: - State / Action

extension PokemonListStore {

    typealias Coordinator = CoordinatorProcotocol & PokemonListCoordinatorProcotocol

    struct State: Equatable {
        var isListLayout: Bool = true
        var isFavoriteFilterOn: Bool = false
        var isLoading: Bool = false
        var alert: AlertState?

        /// 抓回來的全部資料 — 唯一一份
        var cells: [CellViewModel] = []
        /// 目前被收藏的編號,由 store 從 FavoriteUseCase 同步進來
        var favoriteNumbers: Set<Int> = []
        /// 下一頁的 offset,nil 代表已經到底
        var nextOffset: Int? = 0

        /// 畫面實際要顯示的。給定 State 就能算出畫面,不需要問 store。
        var displayCells: [CellViewModel] {
            isFavoriteFilterOn
                ? cells.filter { favoriteNumbers.contains($0.number) }
                : cells
        }

        var isEmpty: Bool { displayCells.isEmpty }
        var hasNextPage: Bool { nextOffset != nil }
    }

    enum Action {
        case onAppear
        case viewWillAppear
        case tapChangeLayout
        case tapFavorite
        case loadMore
        case tapCell(CellViewModel)
        case dismissAlert
    }

    struct Dependency {
        @Injected(\.service.network) var service
        @Injected(\.usecase.favorite) var favorite
        @Injected(\.usecase.list) var list
        let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
        }
    }
}
