//
//  AlertState.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation

/// 要顯示的 alert。錯誤不再走 side channel(ErrorTracker),而是變成 view state 的一部分,
/// 由畫面決定什麼時候呈現、什麼時候清掉。
struct AlertState: Equatable {
    var title: String
    var message: String
}

extension AlertState {
    init(error: Error) {
        self.init(title: "Error ", message: error.localizedDescription)
    }
}
