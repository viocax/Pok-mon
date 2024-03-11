//
//  PokemonShareData.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import Foundation

protocol PokemonShareData {
    func getPokemon() throws -> PokmonResponse
    var spiecs: PokemonSpeciesResponse? { get }
}
