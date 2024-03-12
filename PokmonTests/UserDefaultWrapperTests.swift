//
//  UserDefaultWrapperTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import XCTest
@testable import Pokmon

final class UserDefaultWrapperTests: XCTestCase {
    
    var sutWrapper: UserDefaultWrapper!
    let testKey: String =  "com.drake.Test"
    var injectUserDefault: UserDefaults!

    override func setUp() {
        super.setUp()
        injectUserDefault = .init(suiteName: "com.drake.test")!
        sutWrapper = .init(userDefault: injectUserDefault!, key: testKey)
    }

    func test_wrapper() {
        let value = "element1"
        XCTAssertFalse(sutWrapper.isContain(value))
        XCTAssertTrue(sutWrapper.isEmpty)
        sutWrapper.insert(value)
        sutWrapper.insert(value)
        XCTAssertTrue(sutWrapper.isContain(value))
        XCTAssertFalse(sutWrapper.isEmpty)
        sutWrapper.remove("")
        XCTAssertFalse(sutWrapper.isEmpty)
        sutWrapper.remove(value)
        XCTAssertTrue(sutWrapper.isEmpty)

        sutWrapper.insert(value)
        sutWrapper.synchronize()

        let expect = [value]
        XCTAssertEqual(injectUserDefault.stringArray(forKey: testKey)!, expect)
    }

}
