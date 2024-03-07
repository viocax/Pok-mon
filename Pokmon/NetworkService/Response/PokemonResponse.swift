//
//  PokemonResponse.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Foundation

struct PokemonResponse: Codable {
    struct Item: Codable {
        var name: String
        var url: String
        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<PokemonResponse.Item.CodingKeys> = try decoder.container(keyedBy: PokemonResponse.Item.CodingKeys.self)
            self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
            self.url = (try? container.decode(String.self, forKey: .url)) ?? ""
        }
    }
    let results: [Item]
    let offset: Int?
    let totalCount: Int
    var isEnd: Bool {
        return offset == nil
    }
    enum Key: String, CodingKey {
        case totalCount = "count"
        case nextOffset = "next"
        case results
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        self.results = try container.decode([PokemonResponse.Item].self, forKey: .results)

        self.totalCount = try container.decode(Int.self, forKey: .totalCount)
        let nextPageURLString = try? container.decode(String.self, forKey: .nextOffset)
        guard nextPageURLString?.isEmpty == false else {
            throw URLError(.badServerResponse)
        }
        let urlComponet = URLComponents(string: nextPageURLString ?? "")
        for item in urlComponet?.queryItems ?? [] {
            if item.name == "offset", let value = item.value, let offset = Int(value) {
                self.offset = offset
                return
            }
        }
        self.offset = nil
    }
}
