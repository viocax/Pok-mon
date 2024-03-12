//
//  MockFavoriteUseCase.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
import RxSwift
@testable import Pokmon

class MockFavoriteUseCase: FavoriteUseCase {


    var recordInsert: Int = 0
    func insert(_ element: String) {
        recordInsert += 1
    }

    var recordIsContain: Int = 0
    var injectIsContain = true
    func isContain(_ element: String) -> Bool {
        recordIsContain += 1
        return injectIsContain
    }

    var recordRemove: Int = 0
    func remove(_ element: String) {
        recordRemove += 1
    }
    
    var isEmpty: Bool = false

    var recordSynchronize = 0
    func synchronize() {
        recordSynchronize += 1
    }
}
