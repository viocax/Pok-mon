//
//  ListUseCase.swift
//  Pokmon
//
//  Created by drake on 2024/3/12.
//

import Foundation

protocol ListUsecase {
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel]
}

struct ListUseCaseImp: ListUsecase {
    func listConvertCell(_ items: [PokemonListResponse.Item]) -> [CellViewModel] {
        return items.map { item in
            return CellViewModel(dependency: .init(source: item))
        }
    }
}
