//
//  PokemonListNavigator.swift
//  Pokmon
//
//  Created by drake on 2026/9/2.
//

import UIKit

/// 跟 `PokemonAPIClient` / `FavoritesClient` 同一種注入手法，但**刻意不是 `Sendable`**，
/// 所以進不了 `Dependencies` 的 `@TaskLocal`。
///
/// 那兩個 client 能寫成零參數的 `static let live`，是因為它們的依賴（`APIService.share`、
/// `UserDefaultStore.shared`）是 process 級的單例。導航沒有這種東西——navigation
/// controller 是 per-scene 的，process 啟動當下根本不存在。硬要讓 `live` 變成零參數，
/// 背後就得養一個全域可變的「當前 navigation」，那是把時序陷阱從一個 scene 放大成全域。
///
/// 所以它由 composition root（`PokemonListScene`）建好後從 init 傳進去。
@MainActor
struct PokemonListNavigator {

    /// closure 型別顯式標 `@MainActor`：body 會 push view controller，隔離是承載語意的。
    /// 不標也能編過——closure literal 會繼承外層 context 的隔離——但那等於讓正確性
    /// 取決於「在哪裡建構」，從 nonisolated 的地方建就默默鬆掉了。
    var showDetail: @MainActor (any PokemonShareData) async -> PokemonSpeciesResponse?
}

extension PokemonListNavigator {

    /// 捕捉 navigation controller 而不是 list 的 view controller：push 的對象本來就是它，
    /// 省掉一層 `viewController?.navigationController?` 的可選鏈。
    ///
    /// `[weak navigation]` 切開 navigation → list VC → store → navigator → navigation 這個環。
    static func live(navigation: UINavigationController) -> Self {
        .init(showDetail: { [weak navigation] model in
            guard let pokemon = try? model.getPokemon() else { return nil }

            let store = PokemonDetailStore(pokemon: pokemon, species: model.spiecs)
            let detailViewController = PokemonDeatilPageViewController(store: store)

            return await withCheckedContinuation { continuation in
                detailViewController.onFinish = { continuation.resume(returning: $0) }
                // navigation 已死時不會 push，detailViewController 隨即釋放，
                // 由它的 isolated deinit 呼叫 onFinish(nil) 收掉 continuation。
                // 少了那個 deinit，這裡的 await 會永遠掛住。
                navigation?.pushViewController(detailViewController, animated: true)
            }
        })
    }
}
