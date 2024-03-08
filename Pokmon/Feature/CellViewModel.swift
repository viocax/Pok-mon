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
        let service: NetworkService
        var sepies: PokemonSpeciesResponse?
        let pokemon: PokmonResponse
        init(
            sepies: PokemonSpeciesResponse?,
            pokemon: PokmonResponse,
            service: NetworkService = APIService.share
        ) {
            self.sepies = sepies
            self.pokemon = pokemon
            self.service = service
        }
    }
    struct Input {
        let bindView: Driver<Void>
        let clickIsFavior: Driver<Void>
    }
    struct Output {
        let name: Driver<String>
        let isFavior: Driver<Bool>
        let imageURL: Driver<URL?>
        let isLoading: Driver<Bool>
        let types: Driver<[TypeCornerProtocol]>
        let configuration: Driver<Void>
    }
    func transform(_ input: Input) -> Output {
        
        return .init(
            name: .empty(),
            isFavior: .empty(),
            imageURL: .empty(),
            isLoading: .empty(),
            types: .empty(),
            configuration: .empty()
        )
    }
}
