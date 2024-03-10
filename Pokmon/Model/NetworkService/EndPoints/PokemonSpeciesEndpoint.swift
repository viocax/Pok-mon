//
//  PokemonSpeciesEndpoint.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import Foundation
import Alamofire

struct PokemonSpeciesEndpoint {
    var id: String
}

extension PokemonSpeciesEndpoint: Endpoint {
    typealias Model = PokemonSpeciesResponse
    var path: String {
        return "pokemon-species/\(id)"
    }
    func setupParameter() throws -> Parameters? {
        if id.isEmpty {
            throw PkError.badRequest
        }
        return nil
    }
}
