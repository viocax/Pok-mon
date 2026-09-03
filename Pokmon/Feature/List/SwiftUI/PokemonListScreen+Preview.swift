//
//  PokemonListScreen+Preview.swift
//  Pokmon
//
//  Created by drake on 2026/9/3.
//

#if DEBUG
import SwiftUI

/// Preview 專用的假資料與假 client。
///
/// 這些 client 的形狀跟 `PokmonTests` 裡的 `makeAPI` / `makeFavorites` 一模一樣——
/// 同一套注入手法，測試與 preview 共用，兩邊都不必碰網路。
enum PreviewFixture {

    static func items(_ numbers: [Int]) -> [PokemonListResponse.Item] {
        numbers.compactMap { number in
            try? .init(.init(name: "pokemon-\(number)", url: "https://pokeapi.co/api/v2/pokemon/\(number)"))
        }
    }

    /// `TypeModel` 只有 `init(from:)`，memberwise init 被壓掉了，所以走真正的 decoder。
    static func typeModels(_ types: [PokmonResponse.PokemonType]) -> [PokmonResponse.TypeModel] {
        let elements = types.enumerated().map { index, type in
            #"{"slot":\#(index + 1),"type":{"name":"\#(type.rawValue)","url":""}}"#
        }
        let data = Data("[\(elements.joined(separator: ","))]".utf8)
        return (try? JSONDecoder().decode([PokmonResponse.TypeModel].self, from: data)) ?? []
    }

    static func pokemon(id: Int, name: String, types: [PokmonResponse.PokemonType]) -> PokmonResponse {
        .init(
            id: id,
            name: name,
            height: 7,
            weight: 69,
            sprites: .init(thumbnail: ""),
            species: .init(name: "species", url: ""),
            types: typeModels(types),
            stats: []
        )
    }

    static let names: [Int: (String, [PokmonResponse.PokemonType])] = [
        1: ("bulbasaur", [.grass, .poison]),
        4: ("charmander", [.fire]),
        6: ("charizard", [.fire, .flying]),
        7: ("squirtle", [.water]),
        25: ("pikachu", [.electric]),
        94: ("gengar", [.ghost, .poison])
    ]

    static var api: PokemonAPIClient {
        .init(
            list: { offset in
                // 慢一點，才看得到 loading 與 "Loading..." 的中間態
                try? await Task.sleep(for: .milliseconds(400))
                let page = Array(names.keys.sorted().dropFirst(offset))
                return .init(
                    results: items(Array(page.prefix(3))),
                    offset: page.count > 3 ? offset + 3 : nil,
                    totalCount: names.count
                )
            },
            pokemon: { id in
                try? await Task.sleep(for: .milliseconds(600))
                let (name, types) = names[id] ?? ("unknown", [.normal])
                return pokemon(id: id, name: name, types: types)
            },
            species: { _ in throw PkError.badRequest }
        )
    }

    /// 列表頁只會讀 `contains`——`.tapFavorite` 切的是**過濾器**，
    /// `add` / `remove` 是詳情頁在用的。所以這裡固定一組收藏就夠，
    /// 不需要可變狀態。
    static let favorites: FavoritesClient = {
        let stored: Set<Int> = [4, 25]
        return .init(
            contains: { stored.contains($0) },
            add: { _ in },
            remove: { _ in },
            synchronize: { }
        )
    }()

    /// 導航是唯一**不能**直接搬到 SwiftUI 的部分：`.live` 推的是 `UIViewController`。
    /// 但因為它已經是 client 而不是 protocol，preview 換一個實作就好——
    /// 真正要往 SwiftUI 走的時候，換的也是同一個位置。
    @MainActor
    static var navigator: PokemonListNavigator {
        .init(showDetail: { _ in nil })
    }

    @MainActor
    static var store: PokemonListStore {
        .init(navigator: navigator, api: api, favorites: favorites)
    }
}

#Preview("列表版型") {
    PokemonListScreen(store: PreviewFixture.store)
}

#Preview("單列") {
    PokemonRow(
        model: CellViewModel(
            source: PreviewFixture.items([6])[0],
            api: PreviewFixture.api,
            pokemon: PreviewFixture.pokemon(id: 6, name: "charizard", types: [.fire, .flying])
        )
    )
    .padding()
}
#endif
