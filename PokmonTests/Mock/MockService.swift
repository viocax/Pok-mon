//
//  MockService.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
@testable import Pokmon

@MainActor
final class MockService: NetworkService {

    var injectAsyncResponse: Any?
    var injectAsyncError: Error?
    private(set) var requestedPaths: [String] = []

    func request<T>(_ endpoint: T) async throws -> T.Model where T: Pokmon.Endpoint {
        requestedPaths.append(endpoint.path)
        if let injectAsyncError {
            throw injectAsyncError
        }
        guard let model = injectAsyncResponse as? T.Model else {
            throw PkError.badRequest
        }
        return model
    }
}
