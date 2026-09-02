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

    static func pokemon(
        id: Int,
        name: String = "bulbasaur",
        types: [PokmonResponse.TypeModel] = []
    ) -> PokmonResponse {
        .init(
            id: id,
            name: name,
            height: 7,
            weight: 69,
            sprites: .init(thumbnail: "https://example.com/\(id).png"),
            species: .init(name: "species", url: "url"),
            types: types,
            stats: []
        )
    }

    /// `TypeModel` 只有 `init(from:)`，memberwise init 被壓掉了，所以走真正的 decoder。
    static func typeModels(_ types: [PokmonResponse.PokemonType]) throws -> [PokmonResponse.TypeModel] {
        let elements = types.enumerated().map { index, type in
            #"{"slot":\#(index + 1),"type":{"name":"\#(type.rawValue)","url":""}}"#
        }
        return try JSONDecoder().decode(
            [PokmonResponse.TypeModel].self,
            from: Data("[\(elements.joined(separator: ","))]".utf8)
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
