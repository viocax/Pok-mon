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
    ///
    /// ## 捕捉規則（違反會造成被觀察物件永遠不釋放）
    ///
    /// **`apply` 不可以強捕捉被觀察的物件，也不可以強捕捉持有它的東西。**
    /// 一律透過弱捕捉的 `self` 繞一層去讀。
    ///
    /// ```swift
    /// // ✗ 錯：apply 強捕捉 viewModel
    /// observe { [weak self] in self?.nameLabel.text = viewModel.displayName }
    ///
    /// // ✓ 對：只捕捉弱的 self，物件從 self 身上取
    /// observe { [weak self] in
    ///     guard let self, let viewModel = self.viewModel else { return }
    ///     self.nameLabel.text = viewModel.displayName
    /// }
    /// ```
    ///
    /// 原因：`@Observable` 合成的 registrar 是**被觀察物件自己的儲存屬性**，而 `apply`
    /// 會被註冊到它上面。強捕捉就形成
    /// `viewModel → registrar → onChange → apply → viewModel` 的環，物件自己吊住自己，
    /// 跟觀察者的生命週期無關。
    ///
    /// `cancel()` 擋不掉這個環：它只阻止**下一次**重新掛載，無法註銷已經註冊、尚未
    /// 觸發的那一次，而 Observation 沒有提供主動註銷的 API。該註冊要等被追蹤的屬性
    /// 再變動一次才會釋放——若物件已經沒人會再改它，就永遠不會釋放。
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
