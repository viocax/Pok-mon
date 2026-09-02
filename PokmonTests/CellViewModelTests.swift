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
