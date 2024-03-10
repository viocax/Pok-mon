//
//  PokemonSpeciesResponse.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/10.
//

import Foundation

struct PokemonSpeciesResponse {
    var color: PokomBaseElementInfo
    var flavorEntitys: [FlavorTextEntity]
    var names: [Names]
}

extension PokemonSpeciesResponse: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SpeciesKeys.self)
        self.color = try container.decode(PokomBaseElementInfo.self, forKey: .color)
        self.flavorEntitys = try container.decode([FlavorTextEntity].self, forKey: .flavor)
        self.names = try container.decode([Names].self, forKey: .names)
    }

    enum SpeciesKeys: String, CodingKey {
        case color
        case flavor = "flavor_text_entries"
        case names
    }
    struct Names: Codable, LanguageModel {
        var language: PokomBaseElementInfo
        var name: String
    }
    struct FlavorTextEntity: Codable, LanguageModel {
        var text: String
        var language: PokomBaseElementInfo
        enum Key: String, CodingKey {
            case text = "flavor_text"
            case language
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            self.text = try container.decode(String.self, forKey: .text).split(separator: "\n").joined(separator: " ")
            self.language = try container.decode(PokomBaseElementInfo.self, forKey: .language)
        }
    }
}

protocol LanguageModel {
    var language: PokomBaseElementInfo { get }
    var isCN: Bool { get }
    var isEN: Bool { get }
}
extension LanguageModel {
    var isCN: Bool { language.name == "zh-Hans" }
    var isEN: Bool { language.name == "en" }
}
