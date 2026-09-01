//
//  MockListUSeCase.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
@testable import Pokmon

/// 測試替身只在 MainActor 上使用,不做跨執行緒存取
class MockListUseCase: ListUsecase, @unchecked Sendable {
    var injectCellViewModels: [CellViewModel] = []

    @MainActor
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel] {
        injectCellViewModels
    }
}
