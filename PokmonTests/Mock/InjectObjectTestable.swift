//
//  InjectObjectTestable.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import Foundation
@testable import Pokmon

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
extension CellViewModel.Dependency: InjectObjectTestable { }
extension PokemonDeatilPageViewModel.Dependency: InjectObjectTestable { }
extension PokemonListViewModel.Dependency: InjectObjectTestable { }
