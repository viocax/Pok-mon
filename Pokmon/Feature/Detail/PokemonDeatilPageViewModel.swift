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
        let number: Int
        let pokemon: PokmonResponse
        var spiecs: PokemonSpeciesResponse?
        let coordinator: CoordinatorProcotocol
        let service: NetworkService
        init(
            number: Int,
            spiecs: PokemonSpeciesResponse? = nil,
            pokemon: PokmonResponse,
            coordinator: CoordinatorProcotocol,
            service: NetworkService = APIService.share
        ) {
            self.number = number
            self.spiecs = spiecs
            self.pokemon = pokemon
            self.coordinator = coordinator
            self.service = service
        }
    }
    enum CellDisplayModel {
        case info((PokmonResponse, PokemonSpeciesResponse))
        case abilitity
        case evolution
    }
    struct Input {
        let bindView: Driver<Void>
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
        let number = self.dependency.number

        let spiecs = input.bindView
            .flatMap { _ in
                guard let spiecs = self.dependency.spiecs else {
                    return self.dependency.service
                        .request(PokemonSpeciesEndpoint(id: "\(number)"))
                        .trackActivity(hudTracker)
                        .asDriver(onErrorDriveWith: .empty())
                }
                return .just(spiecs)
            }
        let list = spiecs.map { response in
            return [CellDisplayModel.info((self.dependency.pokemon, response))]
        }

        let title = input.bindView
            .map {
                "No.\(number)"
            }

        return .init(
            title: title,
            list: list,
            spiecs: spiecs,
            configuration: .empty(),
            isEmpty: list.map(\.isEmpty),
            isLoading: hudTracker.asDriver()
        )
    }
}
