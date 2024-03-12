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
    
    var injectShowDetailPage: Observable<PokemonSpeciesResponse?> = .empty()
    func showDetailPage(model: Pokmon.PokemonShareData) -> RxSwift.Observable<Pokmon.PokemonSpeciesResponse?> {
        return injectShowDetailPage
    }
    var injectShowAlert: Observable<Void> = .empty()
    func showAlert(title: String, message: String) -> Observable<Void> {
        return injectShowAlert
    }
}
