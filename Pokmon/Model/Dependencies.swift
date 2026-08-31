//
//  Dependencies.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import Foundation

/// 取代 Swinject 容器。
///
/// 讀取規則：**只在 `Dependency.init` 讀一次並存成 `let`**。
/// `@TaskLocal` 的值是在 `Task` 建立當下捕捉的，若沿用「每次存取才 resolve」
/// 的語義，測試會踩到「Task 建立時機決定讀到誰」——在 `withValue { }` 外
/// 建立的 `Task` 會讀到 live 實作而打到真實網路。
enum Dependencies {
    @TaskLocal static var network: any NetworkService = APIService.share
    @TaskLocal static var favorite: any FavoriteUseCase = UserDefaultStore.shared
    @TaskLocal static var list: any ListUsecase = ListUseCaseImp()
}
