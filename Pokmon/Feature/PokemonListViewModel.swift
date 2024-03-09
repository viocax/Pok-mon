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
        let repository: RepositoryProtocol
        init(
            service: NetworkService = APIService.share,
            repository: RepositoryProtocol = UserDefaultWrapper()
        ) {
            self.service = service
            self.repository = repository
        }
    }
    struct Input {
        let clickFavorite: Driver<Void>
        let bindView: Driver<Void>
        let loadMore: Driver<Bool>
        let clickCell: Driver<CellViewModel>
    }
    struct Output {
        let isFavorite: Driver<Bool>
        let isLoading: Driver<Bool>
        let isEmpty: Driver<Bool>
        let list: Driver<[CellViewModel]>
        let configuration: Driver<Void>
    }
    func transform(_ input: Input) -> Output {
        let hudTracker = HUDTracker()
        let errorTracker = ErrorTracker()

        let listsRelay = BehaviorRelay<[CellViewModel]>(value: [])
        let list = listsRelay
            .asDriver(onErrorDriveWith: .empty())
        let isEmpty = list.map(\.isEmpty)
            .distinctUntilChanged()

        var currentOffset: Int? = 0
        func reciveResponse(_ response: PokemonListResponse) {
            if let offset = response.offset {
                let cell = response.results.enumerated().map { index, item in
                    CellViewModel(dependency: .init(number: index + (currentOffset ?? .zero), source: item))
                }
                currentOffset = offset
                listsRelay.accept(listsRelay.value + cell)
            } else {
                currentOffset = nil
            }
        }

        let loadMore = input.loadMore
            .compactMap { $0 ? () : nil }
        let fetchListEvent = Driver
            .merge(
                loadMore,
                input.bindView
            ).compactMap { currentOffset }
            .flatMap { offset in
                return self.dependency.service
                    .request(PokemonListEndpont(offset: offset))
                    .trackActivity(hudTracker)
                    .trackError(errorTracker)
                    .map(reciveResponse(_:))
                    .asDriver(onErrorDriveWith: .empty())
            }

        var isFavorite = true
        let isFavorteEvent = Driver
            .merge(
                input.bindView,
                input.clickFavorite
            ).map { _ -> Bool in
                isFavorite.toggle()
                return isFavorite
            }
        
        let configuration = Driver
            .merge(
                fetchListEvent
            )

        return .init(
            isFavorite: isFavorteEvent,
            isLoading: hudTracker.asDriver(),
            isEmpty: isEmpty,
            list: list,
            configuration: configuration
        )
    }
}
