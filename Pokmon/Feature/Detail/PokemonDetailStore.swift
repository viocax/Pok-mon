//
//  PokemonDetailStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//
//  Detail 頁的狀態容器:`send(Action)` 進、State 出,非同步工作走 Swift Concurrency。
//  取代原本的 Input/Output/Driver ViewModel。
//

import Combine
import Foundation

@MainActor
final class PokemonDetailStore {

    // MARK: - Properties

    /// 唯一對外的狀態出口。
    ///
    /// `@Published` 是在 `willSet` 發送的,訂閱者收到通知的當下 `viewState` 還是舊值。
    /// 所以畫面不能在 sink 裡回頭讀 `store.viewState` —— 要顯示的資料都由
    /// `Row` 這個 diffable identifier 自己帶著走。
    @Published private(set) var viewState: State = .init()

    private let dependency: Dependency
    private let tasks: TaskStore<TaskKey> = .init()

    private enum TaskKey {
        case load
    }

    /// 給 cell 自己訂閱用 —— 收藏切換時只更新那顆星星,不重建整個 cell
    var isFavoritePublisher: AnyPublisher<Bool, Never> {
        $viewState.map(\.isFavorite).removeDuplicates().eraseToAnyPublisher()
    }

    // MARK: - Life cycle

    init(dependency: Dependency) {
        self.dependency = dependency

        viewState.title = "No.\(dependency.number)"
        viewState.isFavorite = dependency.favorite.isContain("\(dependency.number)")
        viewState.species = dependency.spiecs
    }

    // MARK: - Input

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            load()

        case .tapFavorite(let id):
            toggleFavorite(id)

        case .viewWillDisappear:
            dependency.favorite.synchronize()

        case .dismissAlert:
            // 舊版的 alert 標題就叫「Error and Retry」—— 關掉之後會再打一次
            viewState.alert = nil
            load()
        }
    }

    // MARK: - private

    private func load() {
        guard viewState.species == nil else { return } // 從 List 帶進來就不用再打

        tasks.latest(.load) { [weak self] in
            guard let self else { return }

            self.viewState.isLoading = true
            // 被新請求取代時不要清掉 loading,否則兩個 Task 恢復的先後會讓 loading 閃掉
            defer { if !Task.isCancelled { self.viewState.isLoading = false } }

            do {
                let species: PokemonSpeciesResponse = try await self.dependency.service
                    .request(PokemonSpeciesEndpoint(id: "\(self.dependency.number)"))
                // 取消是協作式的,await 回來不會自己中斷
                guard !Task.isCancelled else { return }

                self.viewState.species = species
            } catch {
                // 取消時丟出來的不一定是 CancellationError,判斷旗標不要比對型別
                guard !Task.isCancelled else { return }

                self.viewState.alert = .init(title: "Error and Retry", message: error.localizedDescription)
            }
        }
    }

    private func toggleFavorite(_ id: Int) {
        let key = "\(id)"
        if dependency.favorite.isContain(key) {
            dependency.favorite.remove(key)
        } else {
            dependency.favorite.insert(key)
        }
        viewState.isFavorite = dependency.favorite.isContain(key)
    }
}

// MARK: - State / Action

extension PokemonDetailStore {

    struct State: Equatable {
        var title: String = ""
        var isLoading: Bool = false
        var isFavorite: Bool = false
        var species: PokemonSpeciesResponse?
        var alert: AlertState?

        /// 資料還沒到就沒有列。`Row` 直接帶著要顯示的資料,
        /// 這樣 cellProvider 不需要回頭讀 store,也就避開 `@Published` 的 willSet 時序問題。
        var rows: [Row] { species.map { [.info($0), .stat] } ?? [] }
        var isEmpty: Bool { rows.isEmpty }
    }

    enum Row: Hashable {
        case info(PokemonSpeciesResponse)
        case stat
    }

    enum Action {
        case onAppear
        case tapFavorite(Int)
        case viewWillDisappear
        case dismissAlert
    }

    /// 交給 `PokemonDetailInfoCell` 的顯示資料。
    ///
    /// `isFavorite` 是 publisher 而不是 Bool:收藏切換時讓 cell 自己更新那顆星星,
    /// 不用 reload 整列 —— cell 裡面還有一個 gender 的 collection view,重建會閃。
    struct Info {
        let pokemon: PokmonResponse
        let species: PokemonSpeciesResponse
        let isFavorite: AnyPublisher<Bool, Never>
    }

    struct Dependency {
        var number: Int { pokemon.id }
        let pokemon: PokmonResponse
        var spiecs: PokemonSpeciesResponse?
        @Injected(\.service.network) var service
        @Injected(\.usecase.favorite) var favorite

        init(spiecs: PokemonSpeciesResponse?, pokemon: PokmonResponse) {
            self.spiecs = spiecs
            self.pokemon = pokemon
        }
    }

    var pokemon: PokmonResponse { dependency.pokemon }
}
