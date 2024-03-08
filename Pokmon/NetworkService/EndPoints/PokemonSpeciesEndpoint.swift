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

struct PokemonSpeciesResponse {
    var color: PokomBaseElementInfo
    var flavorEntitys: [FlavorTextEntity]
}

extension PokemonSpeciesResponse: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SpeciesKeys.self)
        self.color = try container.decode(PokomBaseElementInfo.self, forKey: .color)
        self.flavorEntitys = try container.decode([FlavorTextEntity].self, forKey: .flavor)
    }

    enum SpeciesKeys: String, CodingKey {
        case color
        case flavor = "flavor_text_entries"
    }
    struct FlavorTextEntity: Codable {
        var text: String
        var language: PokomBaseElementInfo
        enum Key: String, CodingKey {
            case text = "flavor_text"
            case language
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            self.text = try container.decode(String.self, forKey: .text)
            self.language = try container.decode(PokomBaseElementInfo.self, forKey: .language)
        }
    }
}
