//
//  PokemonListResponse.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Foundation

struct PokemonListResponse: Codable {
    let results: [Item]
    let offset: Int?
    let totalCount: Int
}

extension PokemonListResponse {
    enum Key: String, CodingKey {
        case totalCount = "count"
        case nextOffset = "next"
        case results
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let infos = try container.decode([PokomBaseElementInfo].self, forKey: .results)
        self.results = try infos.map { try PokemonListResponse.Item($0) }

        self.totalCount = try container.decode(Int.self, forKey: .totalCount)
        let nextPageURLString = try? container.decode(String.self, forKey: .nextOffset)
        guard nextPageURLString?.isEmpty == false else {
            self.offset = nil
            return
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

// MARK: PokemonListResponse.Item
extension PokemonListResponse {
    struct Item: Codable {
        var number: Int
        var name: String
        var url: String
        init(_ info: PokomBaseElementInfo) throws {
            self.name = info.name
            self.url = info.url
            let urlComponet = URLComponents(string: url)
            if let numberString = urlComponet?.path.split(separator: "/").last, let number = Int(numberString) {
                self.number = number
                return
            }
            throw URLError(.badServerResponse)
        }
    }
}
