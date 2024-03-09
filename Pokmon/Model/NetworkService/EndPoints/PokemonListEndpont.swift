//
//  PokemonListEndpont.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire

struct PokemonListEndpont {
    var offset: Int
    var limit: Int
    init(offset: Int, limit: Int = 20) {
        self.offset = offset
        self.limit = limit
    }
}

extension PokemonListEndpont: Endpoint, Codable {
    typealias Model = PokemonListResponse

    var path: String {
        return "pokemon"
    }
    func setupParameter() throws -> Parameters? {
        return try encodeToParameter()
    }
}
