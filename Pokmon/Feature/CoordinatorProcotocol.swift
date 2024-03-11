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
}

final class Coordinator: PokemonListViewModel.Coordinator {

    weak var viewController: UIViewController?
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
