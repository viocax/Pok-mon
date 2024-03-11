//
//  SpeciesUpdatable.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import Foundation

protocol SpeciesUpdatable: AnyObject {
    func updateDetailPage(response sepies: PokemonSpeciesResponse)
}
