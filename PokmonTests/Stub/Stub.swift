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
