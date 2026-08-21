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

        return await withCheckedContinuation { continuation in
            detailViewController.onFinish = { continuation.resume(returning: $0) }
            viewController?.navigationController?.pushViewController(detailViewController, animated: true)
        }
    }
}
