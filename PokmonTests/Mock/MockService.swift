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
}
