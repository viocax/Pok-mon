//
//  UIResponder++Observe.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import Observation
import UIKit

/// `observe` 的取消把手。
///
/// cell 會被重用：重用後如果舊的觀察還在跑，它會繼續往同一批 label 寫上一格的
/// 資料，而且每次 `bindView` 都再疊一組，觀察數隨滾動無上限成長。
/// 所以凡是會 reuse 的呼叫端都必須在 `prepareForReuse` 取消。
/// ViewController 的觀察期等同自身生命週期，可以忽略回傳值。
@MainActor
final class ObservationToken {

    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

@MainActor
extension UIResponder {

    /// 取代 Combine 的 `sink` 與 Rx 的 `drive`。
    ///
    /// `withObservationTracking` 只會通知**一次**，所以 `onChange` 要把自己重新掛回去。
    /// `onChange` 是在值真正寫入**之前**觸發的（willSet 語義），因此不能在 `onChange`
    /// 裡直接讀新值——必須丟進 `Task` 等這一輪寫完再讀，重新掛載時 `apply` 讀到的
    /// 才是新值。
    @discardableResult
    func observe(_ apply: @escaping @MainActor () -> Void) -> ObservationToken {
        let token = ObservationToken()
        observe(token: token, apply)
        return token
    }

    private func observe(token: ObservationToken, _ apply: @escaping @MainActor () -> Void) {
        guard !token.isCancelled else { return }

        withObservationTracking(apply) {
            Task { @MainActor [weak self] in
                guard let self, !token.isCancelled else { return }
                self.observe(token: token, apply)
            }
        }
    }
}
