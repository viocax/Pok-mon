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
        let service: NetworkService
        let repository: FavoriteUseCase
        let coordinator: Coordinator
        init(
            service: NetworkService = APIService.share,
            repository: FavoriteUseCase = UserDefaultWrapper.share,
            coordinator: Coordinator
        ) {
            self.service = service
            self.repository = repository
            self.coordinator = coordinator
        }
    }
    struct Input {
        let clickFavorite: Driver<Void>
        let bindView: Driver<Void>
        let viewWillAppear: Driver<Void>
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
                return cells.filter { self.dependency.repository.isContain("\($0.number)") }
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
            isFavorite: isFavorteEvent,
            isLoading: hudTracker.asDriver(),
            isEmpty: isEmpty,
            list: list,
            configuration: configuration
        )
    }
}

protocol CoordinatorProcotocol {
    var viewController: UIViewController? { get }
    func showAlert(title: String, message: String) -> Observable<Void>
}
extension CoordinatorProcotocol {
    func showAlert(title: String, message: String) -> Observable<Void> {
        return .create { subscriber in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "ok", style: .default) { _ in
                subscriber.onNext(())
                subscriber.onCompleted()
            }
            alert.addAction(okAction)
            self.viewController?.present(alert, animated: true)
            return Disposables.create([
                alert.rx.deallocated.subscribe(subscriber)
            ])
        }
    }
}

protocol SpeciesUpdatable: AnyObject {
    func updateDetailPage(response sepies: PokemonSpeciesResponse)
}
protocol PokemonShareData {
    func getPokemon() throws -> PokmonResponse
    var spiecs: PokemonSpeciesResponse? { get }
}

protocol PokemonListCoordinatorProcotocol {
    func showDetailPage(model: PokemonShareData) -> Observable<PokemonSpeciesResponse?>
}

final class Coordinator: PokemonListViewModel.Coordinator {

    weak var viewController: UIViewController?
    func showDetailPage(model: PokemonShareData) -> Observable<PokemonSpeciesResponse?> {
        return .deferred {
            do {
                let coordinator = Coordinator()
                let viewModel = PokemonDeatilPageViewModel(dependency: .init(spiecs: model.spiecs, pokemon: try model.getPokemon(), coordinator: coordinator))
                let vc = PokemonDeatilPageViewController(viewModel: viewModel)
                coordinator.viewController = vc
                self.viewController?.navigationController?.pushViewController(vc, animated: true)
                return vc.newResponse
            } catch {
                return .error(error)
            }
            
        }
    }
}
