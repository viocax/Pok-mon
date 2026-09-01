//
//  PokemonDetailStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation
import Observation

@Observable
@MainActor
final class PokemonDetailStore {

    // MARK: - Properties

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

    // MARK: - Input

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            load()

        case .tapFavorite(let id):
            toggleFavorite(id)

        case .viewWillDisappear:
            favorites.synchronize()

        case .viewDidDisappear:
            loadTask?.cancel()
            loadTask = nil

        case .dismissAlert:
            viewState.alert = nil
            load()
        }
    }

    // MARK: - private

    private func load() {
        guard viewState.species == nil else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }

            self.viewState.isLoading = true
            // 被取代時不清掉,否則新舊兩個 Task 的恢復順序會讓 loading 閃掉
            defer { if !Task.isCancelled { self.viewState.isLoading = false } }

            do {
                let species = try await self.api.species(self.pokemon.id)
                guard !Task.isCancelled else { return }

                self.viewState.species = species
            } catch {
                // 取消時丟的不一定是 CancellationError,判斷旗標不要比對型別
                guard !Task.isCancelled else { return }

                self.viewState.alert = .init(title: "Error and Retry", message: error.localizedDescription)
            }
        }
    }

    private func toggleFavorite(_ id: Int) {
        // 依儲存決定方向，不依 viewState.isFavorite 這個畫面快取——
        // 兩者不同步時前者才是對的。PokemonDetailStoreTests 有測試釘住這點。
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.add(id)
        }
        viewState.isFavorite = favorites.contains(id)
    }
}

// MARK: - State / Action

extension PokemonDetailStore {

    struct State: Equatable {
        var title: String = ""
        var isLoading: Bool = false
        var isFavorite: Bool = false
        var species: PokemonSpeciesResponse?
        var alert: AlertState?

        var rows: [Row] { species.map { [.info($0), .stat] } ?? [] }
        var isEmpty: Bool { rows.isEmpty }
    }

    enum Row: Hashable {
        case info(PokemonSpeciesResponse)
        case stat
    }

    enum Action {
        case onAppear
        case tapFavorite(Int)
        case viewWillDisappear
        case viewDidDisappear
        case dismissAlert
    }

    struct Info {
        let pokemon: PokmonResponse
        let species: PokemonSpeciesResponse
        /// closure 在 cell 的 `observe` 內被呼叫,讀 store 屬性的動作就完成追蹤註冊,
        /// cell 因此不需要認識 Store 型別。這是 AnyPublisher 欄位的直接對應物。
        let isFavorite: @MainActor () -> Bool
    }

}
