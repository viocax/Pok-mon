//
//  MockService.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
import RxSwift
@testable import Pokmon

/// 測試替身只在 MainActor 上使用，不做跨執行緒存取
class MockService: NetworkService, @unchecked Sendable {

    var injectRequest: Observable<Any> = .empty()
    func request<T>(_ endpoint: T) -> RxSwift.Observable<T.Model> where T: Pokmon.Endpoint {
        return injectRequest.compactMap { $0 as? T.Model }
    }

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
