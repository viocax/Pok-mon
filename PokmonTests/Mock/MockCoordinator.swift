//
//  MockCoordinator.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
import UIKit
import RxSwift
@testable import Pokmon

class MockCoordinator: CoordinatorProcotocol, PokemonListCoordinatorProcotocol {

    
    var viewController: UIViewController?
    
    var injectShowDetailPageAsync: PokemonSpeciesResponse?
    @MainActor
    func showDetailPage(model: Pokmon.PokemonShareData) async -> Pokmon.PokemonSpeciesResponse? {
        return injectShowDetailPageAsync
    }

    var injectShowAlert: Observable<Void> = .empty()
    func showAlert(title: String, message: String) -> Observable<Void> {
        return injectShowAlert
    }
}
