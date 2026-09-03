//
//  PokemonCellTests.swift
//  PokmonTests
//
//  Created by drake on 2026/9/2.
//

import Testing
import UIKit
@testable import Pokmon

@MainActor
@Suite struct PokemonCellTests {

    /// cell 的子 view 都是 `private`，所以從 view hierarchy 撈——
    /// 不為了測試放寬 production 的可見性。
    private struct Subviews {
        let corner: UIView
        let stack: UIStackView
        let image: UIImageView
    }

    private func makeCell() throws -> (PokemonCell, Subviews) {
        let cell = PokemonCell(frame: .init(x: 0, y: 0, width: 180, height: 180))
        let corner = try #require(cell.contentView.subviews.first)
        return (
            cell,
            .init(
                corner: corner,
                stack: try #require(corner.subviews.compactMap { $0 as? UIStackView }.first),
                image: try #require(corner.subviews.compactMap { $0 as? UIImageView }.first)
            )
        )
    }

    /// 全部拋錯：cell 綁定時若真的去打網路，測試會紅而不是靜默通過。
    private func makeAPI() -> PokemonAPIClient {
        .init(
            list: { _ in throw PkError.badRequest },
            pokemon: { _ in throw PkError.badRequest },
            species: { _ in throw PkError.badRequest }
        )
    }

    @Test func 重用後綁定未載入的viewModel不殘留上一隻的屬性與配色() throws {
        let (cell, views) = try makeCell()

        let loaded = CellViewModel(
            source: try Stub.item(6),
            api: makeAPI(),
            pokemon: Stub.pokemon(id: 6, name: "charizard", types: try Stub.typeModels([.fire]))
        )
        cell.bindView(loaded)

        // 先確認前一隻真的把狀態寫進去了，否則後面的斷言證明不了任何事
        #expect(views.stack.arrangedSubviews.contains { $0 is TypeCornerButton })
        #expect(views.corner.layer.borderColor == PokmonResponse.PokemonType.fire.color.cgColor)

        cell.prepareForReuse()

        let notLoaded = CellViewModel(source: try Stub.item(25), api: makeAPI())
        cell.bindView(notLoaded)

        // types 為空時 bindView 的第四個 observe closure 會 early return，
        // 所以這些欄位只可能靠 prepareForReuse 清掉
        #expect(!views.stack.arrangedSubviews.contains { $0 is TypeCornerButton })
        #expect(views.corner.layer.borderColor == UIColor.gray.cgColor)

        notLoaded.cancel()
    }

    @Test func 重用後placeholder會重新轉圈() throws {
        let (cell, views) = try makeCell()

        // 模擬「這個 cell 實例已經載過一次圖」：Kingfisher 的 completion 會 stopRotate，
        // 而那個動畫原本只有 init 加過一次。
        views.image.stopRotate()
        #expect(views.image.layer.animation(forKey: "rotationAnimation") == nil)

        cell.prepareForReuse()

        #expect(views.image.layer.animation(forKey: "rotationAnimation") != nil)
    }
}
