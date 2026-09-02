//
//  GenderImageCollectionCellTests.swift
//  PokmonTests
//
//  Created by drake on 2026/9/2.
//

import Testing
import UIKit
@testable import Pokmon

@MainActor
@Suite struct GenderImageCollectionCellTests {

    /// cell 來自 xib。測試跑在 app host 裡（`TEST_HOST` 有設），所以
    /// `Bundle(for:)` 指到的就是編進 nib 的那個 bundle。
    private func makeCell() throws -> GenderImageCollectionCell {
        let nib = UINib(
            nibName: "GenderImageCollectionCell",
            bundle: Bundle(for: GenderImageCollectionCell.self)
        )
        return try #require(nib.instantiate(withOwner: nil).first as? GenderImageCollectionCell)
    }

    @Test func 重用後placeholder會重新轉圈() throws {
        let cell = try makeCell()

        // 模擬「這個 cell 實例已經載過一次圖」：Kingfisher 的 completion 會 stopRotate，
        // 而那個動畫原本只有 awakeFromNib 掛過一次。
        cell.iconImageView.stopRotate()
        #expect(cell.iconImageView.layer.animation(forKey: "rotationAnimation") == nil)

        cell.prepareForReuse()

        #expect(cell.iconImageView.layer.animation(forKey: "rotationAnimation") != nil)
    }
}
