//
//  Endpoint.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Foundation
import Alamofire

protocol Endpoint {
    associatedtype Model: Codable
    var baseURL: String { get }
    var path: String { get }
    var httpMethod: HTTPMethod { get }
    var httpHeaders: HTTPHeaders { get }
    var endcoder: ParameterEncoding { get }
    func setupParameter() throws -> Parameters?
}

extension Endpoint {
    var baseURL: String {
        return "https://pokeapi.co/api/v2"
    }
    var httpMethod: HTTPMethod {
        return .get
    }
    var httpHeaders: HTTPHeaders {
        return .default
    }
    var endcoder: ParameterEncoding {
        return URLEncoding.default
    }
}
