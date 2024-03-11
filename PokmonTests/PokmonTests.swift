//
//  PokmonTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/7.
//

import XCTest
@testable import Pokmon

final class PokmonTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
protocol InjectObjectTestable {
    /// 多一個參數原因是希望多一點點小限制，顯示的讓呼叫的人傳遞介面進來
    ///
    ///  class Mock: AProtocol { }
    ///  let a = Mock()
    ///  sut.mock(dependency: a, type: AProtocol.self)
    ///
    ///  如果取消參數外面就要在其他地方顯式的宣告型別
    ///  為了避免使用場景多出額外的隱式限制，粗暴地交給程序員。
    ///  let a: AProtocol = Mock()
    ///  sut.mock(dependency: a)
    func mock<T>(dependency: T,_ type: T.Type)
}

extension InjectObjectTestable {
    func mock<T>(dependency: T,_ type: T.Type) {
        InjectObject.shared.container.register(T.self) { _ in
            return dependency
        }.inObjectScope(.container)
    }
}

extension APIService: InjectObjectTestable { }
extension UserDefaultWrapper: InjectObjectTestable { }
