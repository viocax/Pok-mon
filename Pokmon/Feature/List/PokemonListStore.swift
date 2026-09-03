//
//  PokemonListStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation
import Observation

@Observable
@MainActor
final class PokemonListStore {

    // MARK: - Properties

    private(set) var viewState: State = .init()

    private let api: PokemonAPIClient
    private let favorites: FavoritesClient
    private let navigator: PokemonListNavigator

    /// `private(set)` 是為了讓測試能 await 到非同步流程結束
    private(set) var loadTask: Task<Void, Never>?
    private(set) var detailTask: Task<Void, Never>?

    // MARK: - Life cycle

    /// `api` 與 `favorites` 的預設參數是唯一的快照點——`@TaskLocal` 只能在這裡讀。
    init(
        navigator: PokemonListNavigator,
        api: PokemonAPIClient = Dependencies.api,
        favorites: FavoritesClient = Dependencies.favorites
    ) {
        self.navigator = navigator
        self.api = api
        self.favorites = favorites
    }

    // MARK: - Input

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            syncFavorites()
            load()

        case .viewWillAppear:
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

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }

            self.viewState.isLoading = true
            // 被取代時不清掉,否則新舊兩個 Task 的恢復順序會讓 loading 閃掉
            defer { if !Task.isCancelled { self.viewState.isLoading = false } }

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
            } catch {
                // 取消時丟的不一定是 CancellationError,判斷旗標不要比對型別
                guard !Task.isCancelled else { return }

                self.viewState.alert = .init(error: error)
            }
        }
    }

    private func showDetail(_ cell: CellViewModel) {
        detailTask?.cancel()
        detailTask = Task { [weak self] in
            guard let self else { return }

            let species = await self.navigator.showDetail(cell)
            guard !Task.isCancelled, let species else { return }

            cell.updateDetailPage(response: species)
        }
    }

    private func syncFavorites() {
        viewState.favoriteNumbers = Set(
            viewState.cells
                .map(\.number)
                .filter { favorites.contains($0) }
        )
    }
}

// MARK: - State / Action

extension PokemonListStore {

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

    enum Action {
        case onAppear
        case viewWillAppear
        case tapChangeLayout
        case tapFavorite
        case loadMore
        case tapCell(CellViewModel)
        case dismissAlert
    }

}
