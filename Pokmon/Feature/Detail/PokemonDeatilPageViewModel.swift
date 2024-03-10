//
//  PokemonDeatilPageViewModel.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/10.
//

import RxSwift
import RxCocoa

final class PokemonDeatilPageViewModel {
    private let dependency: Dependency
    init(dependency: Dependency) {
        self.dependency = dependency
    }
}

extension PokemonDeatilPageViewModel {
    struct Dependency {
        var number: Int {
            return pokemon.id
        }
        let pokemon: PokmonResponse
        var spiecs: PokemonSpeciesResponse?
        let coordinator: CoordinatorProcotocol
        let service: NetworkService
        let favoriteUseCase: FavoriteUseCase
        init(
            spiecs: PokemonSpeciesResponse? = nil,
            pokemon: PokmonResponse,
            coordinator: CoordinatorProcotocol,
            service: NetworkService = APIService.share,
            favorite: FavoriteUseCase = UserDefaultWrapper.share
        ) {
            self.spiecs = spiecs
            self.pokemon = pokemon
            self.coordinator = coordinator
            self.service = service
            self.favoriteUseCase = favorite
        }
    }
    struct Info {
        var pokemon: PokmonResponse
        var species: PokemonSpeciesResponse
        var _isFavorite: BehaviorRelay<Bool>
        var isFavorite: Observable<Bool> {
            return _isFavorite.asObservable()
        }
    }
    enum CellDisplayModel {
        case info(Info)
        case stat(PokmonResponse)
        case abilitity
        case evolution
    }
    struct Input {
        let bindView: Driver<Void>
        let isFavorite: Driver<Int>
    }
    struct Output {
        let title: Driver<String>
        let list: Driver<[CellDisplayModel]>
        let spiecs: Driver<PokemonSpeciesResponse>
        let configuration: Driver<Void>
        let isEmpty: Driver<Bool>
        let isLoading: Driver<Bool>
    }
    func transform(_ input: Input) -> Output {
        let hudTracker = HUDTracker()
        let errorTracker = ErrorTracker()
        let number = self.dependency.number
        

        let isFavoriteState = BehaviorRelay<Bool>(value: self.dependency.favoriteUseCase.isContain("\(number)"))

        let recodeTapIsFavorite = input.isFavorite
            .map { newIndex in
                let isContain = self.dependency.favoriteUseCase.isContain("\(newIndex)")
                if isContain {
                    self.dependency.favoriteUseCase.remove("\(newIndex)")
                } else {
                    self.dependency.favoriteUseCase.insert("\(newIndex)")
                }
                return isFavoriteState.accept(!isContain)
            }

        let retry = errorTracker
            .flatMap { error in
                return self.dependency.coordinator
                    .showAlert(title: "Error and Retry", message: error.localizedDescription)
                    .asDriver(onErrorDriveWith: .empty())
            }

        let spiecs = Driver
            .merge(
                input.bindView, 
                retry
            )
            .flatMap { _ in
                guard let spiecs = self.dependency.spiecs else {
                    return self.dependency.service
                        .request(PokemonSpeciesEndpoint(id: "\(number)"))
                        .trackError(errorTracker)
                        .trackActivity(hudTracker)
                        .asDriver(onErrorDriveWith: .empty())
                }
                return .just(spiecs)
            }
        let list = spiecs.map { response -> [CellDisplayModel] in
            return [
                .info(.init(
                    pokemon: self.dependency.pokemon,
                    species: response,
                    _isFavorite: isFavoriteState
                )),
                .stat(self.dependency.pokemon)
            ]
        }

        let title = input.bindView
            .map {
                "No.\(number)"
            }

        let configuration = Driver
            .merge(
                recodeTapIsFavorite
            )

        return .init(
            title: title,
            list: list,
            spiecs: spiecs,
            configuration: configuration,
            isEmpty: list.map(\.isEmpty),
            isLoading: hudTracker.asDriver()
        )
    }
}
