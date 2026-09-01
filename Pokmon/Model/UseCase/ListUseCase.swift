//
//  ListUseCase.swift
//  Pokmon
//
//  Created by drake on 2024/3/12.
//

import Foundation

protocol ListUsecase: Sendable {
    @MainActor
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel]
}

struct ListUseCaseImp: ListUsecase {
    @MainActor
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel] {
        items.map { CellViewModel(source: $0) }
    }
}
