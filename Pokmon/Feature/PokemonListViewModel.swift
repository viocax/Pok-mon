//
//  PokemonListViewModel.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import RxCocoa
import RxSwift

final class PokemonListViewModel {
    private let dependency: Dependency
    init(dependency: Dependency) {
        self.dependency = dependency
    }
}

extension PokemonListViewModel {
    struct Dependency {
        let service: NetworkService
        init(service: NetworkService = APIService.share) {
            self.service = service
        }
    }
    struct Input {
        let bindView: Driver<Void>
        let loadMore: Driver<Void>
        let clickCell: Driver<CellViewModel>
    }
    struct Output {
        let isLoading: Driver<Bool>
        let isEmpty: Driver<Bool>
        let list: Driver<[CellViewModel]>
        let configuration: Driver<Void>
    }
    func transform(_ input: Input) -> Output {
        return .init(
            isLoading: .empty(),
            isEmpty: .empty(),
            list: .empty(),
            configuration: .empty()
        )
    }
}

