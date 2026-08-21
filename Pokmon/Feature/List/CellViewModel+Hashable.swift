//
//  CellViewModel+Hashable.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation

/// hash 要跟 `==` 用同一個欄位
extension CellViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}
