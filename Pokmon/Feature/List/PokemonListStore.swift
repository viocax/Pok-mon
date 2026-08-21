//
//  PokemonListStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Combine
import Foundation

@MainActor
final class PokemonListStore {

    // MARK: - Properties

    @Published private(set) var viewState: State = .init()

    private let dependency: Dependency

    private var loadTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?

    // MARK: - Life cycle

    init(dependency: Dependency) {
        self.dependency = dependency
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
                let response: PokemonListResponse = try await self.dependency.service
                    .request(PokemonListEndpont(offset: offset))
                guard !Task.isCancelled else { return }

                self.viewState.nextOffset = response.offset
                self.viewState.cells += self.dependency.list.listConvertCell(response.results)
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

            let species = await self.dependency.coordinator.showDetailPage(model: cell)
            guard !Task.isCancelled, let species else { return }

            cell.updateDetailPage(response: species)
        }
    }

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
