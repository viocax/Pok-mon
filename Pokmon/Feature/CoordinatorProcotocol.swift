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
    func showDetailPage(model: PokemonShareData) -> Observable<PokemonSpeciesResponse?>

    /// Concurrency 版。標 @MainActor 是因為裡面要推 view controller ——
    /// 舊的 Observable 版把 push 藏在 `.deferred` 裡,編譯器看不出這個限制,
    /// 只是靠呼叫端剛好在主執行緒訂閱才對的。
    @MainActor
    func showDetailPage(model: PokemonShareData) async -> PokemonSpeciesResponse?
}

final class Coordinator: PokemonListViewModel.Coordinator {

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

    func showDetailPage(model: PokemonShareData) -> Observable<PokemonSpeciesResponse?> {
        return .deferred {
            do {
                let coordinator = Coordinator()
                let viewModel = PokemonDeatilPageViewModel(dependency: .init(spiecs: model.spiecs, pokemon: try model.getPokemon(), coordinator: coordinator))
                let vc = PokemonDeatilPageViewController(viewModel: viewModel)
                coordinator.viewController = vc
                self.viewController?.navigationController?.pushViewController(vc, animated: true)
                return vc.newResponse
            } catch {
                return .error(error)
            }
            
        }
    }
}
