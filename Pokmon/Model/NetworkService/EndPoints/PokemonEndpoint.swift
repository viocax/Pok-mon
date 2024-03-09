//
//  PokemonEndpoint.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import Alamofire

struct PokemonEndpoint {
    var id: String
}

extension PokemonEndpoint: Endpoint {
    typealias Model = PokmonResponse
    var path: String {
        return "pokemon/\(id)"
    }
    func setupParameter() throws -> Parameters? {
        if id.isEmpty { throw PkError.badRequest }
        return nil
    }
}
