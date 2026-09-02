//
//  PokemonListScene.swift
//  Pokmon
//
//  Created by drake on 2026/9/2.
//

import UIKit

/// list 這一屏的 composition root。
///
/// navigation controller 先建空的，才能在 store 出生前就交給 navigator——
/// 換掉了舊寫法「先建 coordinator、建完 store 與 VC 再回填 `coordinator.viewController`」
/// 的那段空窗期。
enum PokemonListScene {

    @MainActor
    static func make() -> UIViewController {
        let navigation = UINavigationController()
        let store = PokemonListStore(navigator: .live(navigation: navigation))
        navigation.viewControllers = [PokemonListViewController(store: store)]
        return navigation
    }
}
