//
//  FavoritesClient.swift
//  Pokmon
//
//  Created by drake on 2026/9/1.
//

import Foundation

/// 名字刻意不叫 `DBClient`——背後是 `UserDefaults`，不是資料庫。
///
/// closure 是同步的，所以 `UserDefaultStore` 內部的 `OSAllocatedUnfairLock`
/// 仍然必要。換成 Client 不會讓併發安全變成免費的。
struct FavoritesClient: Sendable {
    var contains: @Sendable (_ id: Int) -> Bool
    var add: @Sendable (_ id: Int) -> Void
    var remove: @Sendable (_ id: Int) -> Void
    var synchronize: @Sendable () -> Void
}

extension FavoritesClient {

    /// id 的字串化是 `UserDefaults` 鍵值的細節，收在這裡。
    static let live: FavoritesClient = {
        let store = UserDefaultStore.shared
        return .init(
            contains: { store.isContain("\($0)") },
            add: { store.insert("\($0)") },
            remove: { store.remove("\($0)") },
            synchronize: { store.synchronize() }
        )
    }()
}
