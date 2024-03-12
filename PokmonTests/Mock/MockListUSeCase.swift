//
//  MockListUSeCase.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
@testable import Pokmon

class MockListUseCase: ListUsecase {
    var injectCellViewModels: [CellViewModel] = []
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel] {
        injectCellViewModels
    }
}
