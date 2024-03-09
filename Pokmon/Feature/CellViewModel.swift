//
//  CellViewModel.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import RxSwift
import RxCocoa

final class CellViewModel {
    private let dependency: Dependency
    init(dependency: Dependency) {
        self.dependency = dependency
    }
}

extension CellViewModel {
    class Dependency {
        let number: Int
        let service: NetworkService
        var sepies: PokemonSpeciesResponse?
        var pokemon: PokmonResponse?
        let source: PokemonListResponse.Item
        let repository: RepositoryProtocol
        init(
            number: Int,
            sepies: PokemonSpeciesResponse? = nil,
            pokemon: PokmonResponse? = nil,
            source: PokemonListResponse.Item,
            service: NetworkService = APIService.share,
            repository: RepositoryProtocol = UserDefaultWrapper()
        ) {
            self.number = number
            self.sepies = sepies
            self.pokemon = pokemon
            self.source = source
            self.service = service
            self.repository = repository
        }
    }
    struct Input {
        let bindView: Driver<Void>
    }
    struct Output {
        let number: Driver<String>
        let name: Driver<String>
        let height: Driver<Int>
        let width: Driver<Int>
        let imageURL: Driver<String>
        let types: Driver<[TypeCornerProtocol]>
    }
    func transform(_ input: Input) -> Output {
        let hudTracker = HUDTracker()
        let number = self.dependency.source.number

        let pokemon = input.bindView
            .flatMap {
                guard let pokemon = self.dependency.pokemon else {
                    return self.dependency.service
                        .request(PokemonEndpoint(id: "\(number)"))
                        .trackActivity(hudTracker)
                        .do(onNext: { response in
                            self.dependency.pokemon = response
                        })
                        .asDriver(onErrorDriveWith: .empty())
                }
                return .just(pokemon)
            }

        let species = input.bindView
            .flatMap { _ in
                guard let species = self.dependency.sepies else {
                    return self.dependency.service
                        .request(PokemonSpeciesEndpoint(id: "\(number)"))
                        .do(onNext: { response in
                            self.dependency.sepies = response
                        })
                        .asDriver(onErrorDriveWith: .empty())
                }
                return .just(species)
            }

        let getTypes = pokemon
            .map { response -> [any TypeCornerProtocol] in
                return response.types.map(\.type)
            }
        let loading = hudTracker.distinctUntilChanged()
            .compactMap {
                return $0 ? "Loading..." : nil
            }
            
        let name = Driver
            .merge(
                loading,
                pokemon.map { $0.name }
            )
        let numberOutput = input.bindView
            .map { "No.\(number)" }
        
        return .init(
            number: numberOutput,
            name:  name,
            height: pokemon.map(\.height),
            width: pokemon.map(\.weight),
            imageURL: pokemon.map(\.sprites.image),
            types: getTypes
        )
    }
}
