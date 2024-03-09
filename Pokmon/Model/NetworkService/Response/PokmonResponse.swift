//
//  PokmonResponse.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import Foundation
import class UIKit.UIColor

struct PokmonResponse {
    var name: String
    var height: Int
    var weight: Int
    var sprites: Sprite
    var species: PokomBaseElementInfo
    var types: [TypeModel]
    var stats: [Stat]
}

extension PokmonResponse: Codable {
    struct Sprite: Codable {
        var image: String
        var female: String?
        enum Key: String, CodingKey {
            case image = "front_default"
            case female = "front_female"
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            self.image = try container.decode(String.self, forKey: .image)
            self.female = try container.decodeIfPresent(String.self, forKey: .female)
        }
    }
    enum StatType: String, CaseIterable, Codable {
        case hp, speed, attack, defense
        case specialDefense = "special-defense"
        case specialAttack = "special-attack"
    }
    struct Stat: Codable {
        var baseStat: Int
        var effort: Int
        var stat: StatType
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            self.baseStat = try container.decode(Int.self, forKey: .baseStat)
            self.effort = try container.decode(Int.self, forKey: .effort)
            let info = try container.decode(PokomBaseElementInfo.self, forKey: .stat)
            if let type = StatType(rawValue: info.name) {
                self.stat = type
            } else {
                throw URLError(.badServerResponse)
            }
        }
        enum Key: String, CodingKey {
            case stat, effort
            case baseStat = "base_stat"
        }
    }
    struct TypeModel: Codable {
        var slot: Int
        var type: PokemonType
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.slot = try container.decode(Int.self, forKey: .slot)
            let info = try container.decode(PokomBaseElementInfo.self, forKey: .type)
            if let type = PokemonType(rawValue: info.name) {
                self.type = type
            } else {
                throw URLError(.badServerResponse)
            }
        }
    }
}

// MARK: PokmonResponse.Type
extension PokmonResponse {
    enum PokemonType: String, Codable, TypeCornerProtocol {
        case normal
        case fighting
        case flying
        case poison
        case ground
        case rock
        case bug
        case ghost
        case steel
        case fire
        case water
        case grass
        case electric
        case psychic
        case ice
        case dragon
        case dark
        case fairy
        case unknown
        case shadow
        var color: UIColor {
            switch self {
            case .normal:
                return .hex(0xBBBBAC)
            case .fighting:
                return .hex(0xAE5B4A)
            case .flying:
                return .hex(0x7199F8)
            case .poison:
                return .hex(0x9F5A96)
            case .ground:
                return .hex(0xD8BC65)
            case .rock:
                return .hex(0xB8AA6F)
            case .bug:
                return .hex(0xADBA44)
            case .ghost:
                return .hex(0x6667B5)
            case .steel:
                return .hex(0xAAAABA)
            case .fire:
                return .hex(0xEB5435)
            case .water:
                return .hex(0x5198F7)
            case .grass:
                return .hex(0x8BC965)
            case .electric:
                return .hex(0xF7CD55)
            case .psychic:
                return .hex(0xEC6298)
            case .ice:
                return .hex(0x90DBFB)
            case .dragon:
                return .hex(0x7469E6)
            case .dark:
                return .hex(0x725647)
            case .fairy:
                return .hex(0xF3AFFA)
            case .unknown:
                return .hex(0x749E91)
            case .shadow:
                return .hex(0x9F5A96)
            }
        }
        var name: String {
            switch self {
            case .normal:
                return "一般"
            case .fighting:
                return "格斗"
            case .flying:
                return "飛行"
            case .poison:
                return "毒"
            case .ground:
                return "地面"
            case .rock:
                return "岩石"
            case .bug:
                return "蟲"
            case .ghost:
                return "幽靈"
            case .steel:
                return "鋼"
            case .fire:
                return "火"
            case .water:
                return "水"
            case .grass:
                return "草"
            case .electric:
                return "電"
            case .psychic:
                return "超能力"
            case .ice:
                return "冰"
            case .dragon:
                return "龍"
            case .dark:
                return "恶"
            case .fairy:
                return "妖精"
            case .unknown:
                return "???"
            case .shadow:
                return "暗"
            }
        }
    }
}
