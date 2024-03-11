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
    typealias Coordinator = CoordinatorProcotocol & PokemonListCoordinatorProcotocol
    struct Dependency {
        @Injected(\.service.network) var service
        @Injected(\.usecase.favorite) var favorite
        let coordinator: Coordinator
        init(
            coordinator: Coordinator
        ) {
            self.coordinator = coordinator
        }
    }
    struct Input {
        let changeLayout: Driver<Void>
        let clickFavorite: Driver<Void>
        let bindView: Driver<Void>
        let viewWillAppear: Driver<Void>
        let loadMore: Driver<Bool>
        let clickCell: Driver<CellViewModel>
    }
    struct Output {
        let isListOrGrid: Driver<Bool>
        let isFavorite: Driver<Bool>
        let isLoading: Driver<Bool>
        let isEmpty: Driver<Bool>
        let list: Driver<[CellViewModel]>
        let configuration: Driver<Void>
    }
    func transform(_ input: Input) -> Output {
        let hudTracker = HUDTracker()
        let errorTracker = ErrorTracker()

        var isListOrGrid = true
        let changeLayout = input.changeLayout
            .map { _ in
                isListOrGrid.toggle()
                return isListOrGrid
            }
        let isListOrGridOutput = Driver
            .merge(
                changeLayout,
                .just(isListOrGrid)
            )

        var isFavorite = true
        let isFavorteEvent = Driver
            .merge(
                input.bindView,
                input.clickFavorite
            ).map { _ -> Bool in
                isFavorite.toggle()
                return isFavorite
            }

        let listsRelay = BehaviorRelay<[CellViewModel]>(value: [])
        let shareList = listsRelay.asDriver()
        let viewWillAppear = input.viewWillAppear
            .withLatestFrom(shareList)

        let list = Driver
            .merge(
                shareList,
                viewWillAppear,
                isFavorteEvent.withLatestFrom(shareList)
            )
            .map { cells -> [CellViewModel] in
                guard isFavorite else {
                    return cells
                }
                return cells.filter { self.dependency.favorite.isContain("\($0.number)") }
            }
            .asDriver(onErrorDriveWith: .empty())
        let isEmpty = list.map(\.isEmpty)
            .distinctUntilChanged()

        var currentOffset: Int? = 0
        func reciveResponse(_ response: PokemonListResponse) {
            if let offset = response.offset {
                let cell = response.results.map { item in
                    CellViewModel(dependency: .init(source: item))
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
            .flatMapLatest { offset in
                return self.dependency.service
                    .request(PokemonListEndpont(offset: offset))
                    .trackActivity(hudTracker)
                    .trackError(errorTracker)
                    .map(reciveResponse(_:))
                    .asDriver(onErrorDriveWith: .empty())
            }



        let gotoDetailPage = input.clickCell
            .flatMap { cellViewModel in
                return self.dependency.coordinator
                    .showDetailPage(model: cellViewModel)
                    .map { newResposen in
                        if let new = newResposen { cellViewModel.updateDetailPage(response: new) }
                        return ()
                    }
                    .asDriver(onErrorDriveWith: .empty())
            }

        let alert = errorTracker
            .flatMap { error in
                return self.dependency.coordinator
                    .showAlert(title: "Error ", message: error.localizedDescription)
                    .asDriver(onErrorDriveWith: .empty())
            }
        
        let configuration = Driver
            .merge(
                fetchListEvent,
                alert,
                gotoDetailPage
            )

        return .init(
            isListOrGrid: isListOrGridOutput,
            isFavorite: isFavorteEvent,
            isLoading: hudTracker.asDriver(),
            isEmpty: isEmpty,
            list: list,
            configuration: configuration
        )
    }
}

