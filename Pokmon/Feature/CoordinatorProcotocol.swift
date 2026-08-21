//
//  CoordinatorProcotocol.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import UIKit
import RxSwift

protocol CoordinatorProcotocol {
    var viewController: UIViewController? { get }
    func showAlert(title: String, message: String) -> Observable<Void>
}
extension CoordinatorProcotocol {
    func showAlert(title: String, message: String) -> Observable<Void> {
        return .create { subscriber in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "ok", style: .default) { _ in
                subscriber.onNext(())
                subscriber.onCompleted()
            }
            alert.addAction(okAction)
            self.viewController?.present(alert, animated: true)
            return Disposables.create([
                alert.rx.deallocated.subscribe(subscriber)
            ])
        }
    }
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

        let child = Coordinator()
        let viewModel = PokemonDeatilPageViewModel(
            dependency: .init(spiecs: model.spiecs, pokemon: pokemon, coordinator: child)
        )
        let detailViewController = PokemonDeatilPageViewController(viewModel: viewModel)
        child.viewController = detailViewController
        viewController?.navigationController?.pushViewController(detailViewController, animated: true)

        // Detail 頁內部還是 Rx,只在這個邊界橋接一次
        return await detailViewController.newResponse.firstValue() ?? nil
    }
}
