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
        sutStore.insert(value)
        sutStore.insert(value)
        XCTAssertTrue(sutStore.isContain(value))
        // 移除不存在的元素不影響既有內容
        sutStore.remove("")
        XCTAssertTrue(sutStore.isContain(value))
        sutStore.remove(value)
        XCTAssertFalse(sutStore.isContain(value))

        sutStore.insert(value)
        sutStore.synchronize()

        // 插入兩次只會存成一筆 —— 這條斷言守著集合語義
        XCTAssertEqual(injectUserDefault.stringArray(forKey: testKey), [value])
    }
}
