//
//  CellViewModel+Hashable.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation

/// `UICollectionViewDiffableDataSource` 的 item identifier 必須是 Hashable。
/// `CellViewModel` 已經用 `number` 實作 `==`,這裡的 hash 跟著用同一個欄位才會一致。
extension CellViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}
