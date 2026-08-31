//
//  PokemonDetailStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Combine
import Foundation

@MainActor
final class PokemonDetailStore {

    // MARK: - Properties

    @Published private(set) var viewState: State = .init()

    private let dependency: Dependency

    private var loadTask: Task<Void, Never>?

    var isFavoritePublisher: AnyPublisher<Bool, Never> {
        $viewState.map(\.isFavorite).removeDuplicates().eraseToAnyPublisher()
    }

    // MARK: - Life cycle

    init(dependency: Dependency) {
        self.dependency = dependency

        viewState.title = "No.\(dependency.number)"
        viewState.isFavorite = dependency.favorite.isContain("\(dependency.number)")
        viewState.species = dependency.spiecs
    }

    // MARK: - Input

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            load()

        case .tapFavorite(let id):
            toggleFavorite(id)

        case .viewWillDisappear:
            dependency.favorite.synchronize()

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
                let species: PokemonSpeciesResponse = try await self.dependency.service
                    .request(PokemonSpeciesEndpoint(id: "\(self.dependency.number)"))
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
        let key = "\(id)"
        if dependency.favorite.isContain(key) {
            dependency.favorite.remove(key)
        } else {
            dependency.favorite.insert(key)
        }
        viewState.isFavorite = dependency.favorite.isContain(key)
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
        let isFavorite: AnyPublisher<Bool, Never>
    }

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

    var pokemon: PokmonResponse { dependency.pokemon }
}
