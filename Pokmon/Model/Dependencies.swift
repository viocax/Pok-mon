//
//  Dependencies.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import Foundation

/// 取代 Swinject 容器。
///
/// 讀取規則：**只能在 init 的預設參數位置讀，讀到就存成 `let`**。
/// `@TaskLocal` 的值是在 `Task` 建立當下捕捉的，若在方法內（尤其 `Task { }`
/// 內）才讀，就會變成「Task 建立時機決定讀到誰」——在 `withValue { }` 外
/// 建立的 `Task` 會讀到 live 實作而打到真實網路。
enum Dependencies {

    @TaskLocal static var api: PokemonAPIClient = .live
    @TaskLocal static var favorites: FavoritesClient = .live

    // MARK: - 以下三項正在被上面兩個 Client 取代，最後一步會移除

    @TaskLocal static var network: any NetworkService = APIService.share
    @TaskLocal static var favorite: any FavoriteUseCase = UserDefaultStore.shared
    @TaskLocal static var list: any ListUsecase = ListUseCaseImp()
}
