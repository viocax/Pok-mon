//
//  CoordinatorProcotocol.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import UIKit

protocol CoordinatorProcotocol {
    var viewController: UIViewController? { get }
}

protocol PokemonListCoordinatorProcotocol {
    /// 標 @MainActor 是因為裡面要推 view controller,讓它變成編譯期保證
    @MainActor
    func showDetailPage(model: PokemonShareData) async -> PokemonSpeciesResponse?
}

final class Coordinator: PokemonListStore.Coordinator {

    weak var viewController: UIViewController?

    @MainActor
    func showDetailPage(model: PokemonShareData) async -> PokemonSpeciesResponse? {
        guard let pokemon = try? model.getPokemon() else { return nil }

        let store = PokemonDetailStore(dependency: .init(spiecs: model.spiecs, pokemon: pokemon))
        let detailViewController = PokemonDeatilPageViewController(store: store)

        // 等到使用者離開 Detail 頁才回傳 —— onFinish 保證只會被呼叫一次
        return await withCheckedContinuation { continuation in
            detailViewController.onFinish = { continuation.resume(returning: $0) }
            viewController?.navigationController?.pushViewController(detailViewController, animated: true)
        }
    }
}
