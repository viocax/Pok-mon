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
        var number: Int {
            return source.number
        }
        var sepies: PokemonSpeciesResponse?
        var pokemon: PokmonResponse?
        let source: PokemonListResponse.Item
        @Injected(\.service.network) var service
        init(
            sepies: PokemonSpeciesResponse? = nil,
            pokemon: PokmonResponse? = nil,
            source: PokemonListResponse.Item
        ) {
            self.sepies = sepies
            self.pokemon = pokemon
            self.source = source
        }
    }
    struct Input {
        let bindView: Driver<Void>
    }
    struct Output {
        let number: Driver<String>
        let name: Driver<String>
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
            imageURL: pokemon.map(\.sprites.thumbnail),
            types: getTypes
        )
    }
}

extension CellViewModel: SpeciesUpdatable {
    func updateDetailPage(response sepies: PokemonSpeciesResponse) {
        self.dependency.sepies = sepies
    }
}

extension CellViewModel: PokemonShareData, Equatable {
    static func == (lhs: CellViewModel, rhs: CellViewModel) -> Bool {
        return lhs.dependency.number == rhs.dependency.number
    }
    
    var number: Int {
        return dependency.number
    }
    func getPokemon() throws -> PokmonResponse {
        guard let pokemon = self.dependency.pokemon else {
            throw PkError.pokemonDataNotYet
        }
        return pokemon
    }
    var spiecs: PokemonSpeciesResponse? {
        return dependency.sepies
    }
}
