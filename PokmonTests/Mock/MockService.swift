//
//  MockService.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
import RxSwift
@testable import Pokmon

class MockService: NetworkService {

    var injectRequest: Observable<Any> = .empty()
    func request<T>(_ endpoint: T) -> RxSwift.Observable<T.Model> where T: Pokmon.Endpoint {
        return injectRequest.compactMap { $0 as? T.Model }
    }

    /// NetworkService 多了 concurrency 版,這裡跟著補上以符合協定
    var injectAsyncResponse: Any?
    var injectAsyncError: Error?
    func request<T>(_ endpoint: T) async throws -> T.Model where T: Pokmon.Endpoint {
        if let injectAsyncError {
            throw injectAsyncError
        }
        guard let model = injectAsyncResponse as? T.Model else {
            throw PkError.badRequest
        }
        return model
    }
}
