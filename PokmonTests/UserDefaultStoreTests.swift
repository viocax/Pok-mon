//
//  UserDefaultStoreTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import XCTest
@testable import Pokmon

final class UserDefaultStoreTests: XCTestCase {

    var sutStore: UserDefaultStore!
    let testKey: String = "com.drake.Test"
    var injectUserDefault: UserDefaults!

    override func setUp() {
        super.setUp()
        injectUserDefault = .init(suiteName: "com.drake.test")!
        injectUserDefault.removeObject(forKey: testKey)
        sutStore = .init(userDefault: injectUserDefault, key: testKey)
    }

    func test_store() {
        let value = "element1"
        XCTAssertFalse(sutStore.isContain(value))
        XCTAssertTrue(sutStore.isEmpty)
        sutStore.insert(value)
        sutStore.insert(value)
        XCTAssertTrue(sutStore.isContain(value))
        XCTAssertFalse(sutStore.isEmpty)
        sutStore.remove("")
        XCTAssertFalse(sutStore.isEmpty)
        sutStore.remove(value)
        XCTAssertTrue(sutStore.isEmpty)

        sutStore.insert(value)
        sutStore.synchronize()

        XCTAssertEqual(injectUserDefault.stringArray(forKey: testKey), [value])
    }
}
