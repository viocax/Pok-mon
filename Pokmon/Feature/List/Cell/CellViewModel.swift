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
