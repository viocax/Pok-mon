//
//  PkError.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import Foundation

enum PkError: Error {
    case badRequest
    case urlError(URLError)
    case afError(AFError)
    case unknown(Error)
    case pokemonDataNotYet
}
