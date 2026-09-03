//
//  PokemonListStoreTests.swift
//  PokmonTests
//
//  Created by drake on 2026/8/31.
//

import Testing
@testable import Pokmon

@MainActor
@Suite struct PokemonListStoreTests {

    /// 未指定的 closure 給明確拋錯的實作，誤呼叫時測試會紅而不是靜默通過。
    private func makeAPI(
        list: @escaping @Sendable (Int) async throws -> PokemonListResponse = { _ in
            throw PkError.badRequest
        }
    ) -> PokemonAPIClient {
        .init(
            list: list,
            pokemon: { _ in throw PkError.badRequest },
            species: { _ in throw PkError.badRequest }
        )
    }

    /// `contains` 讀一個可變的旗標，讓測試中途能翻轉收藏狀態。
    private func makeFavorites(
        contains: @escaping @Sendable (Int) -> Bool = { _ in false }
    ) -> FavoritesClient {
        .init(
            contains: contains,
            add: { _ in },
            remove: { _ in },
            synchronize: { }
        )
    }

    /// 未指定時回 nil，等同「使用者離開詳細頁但沒帶回 species」。
    private func makeNavigator(
        showDetail: @escaping @MainActor (any PokemonShareData) async -> PokemonSpeciesResponse? = { _ in nil }
    ) -> PokemonListNavigator {
        .init(showDetail: showDetail)
    }

    private func makeStore(
        api: PokemonAPIClient? = nil,
        favorites: FavoritesClient? = nil,
        navigator: PokemonListNavigator? = nil
    ) -> PokemonListStore {
        PokemonListStore(
            navigator: navigator ?? makeNavigator(),
            api: api ?? makeAPI(),
            favorites: favorites ?? makeFavorites()
        )
    }

    @Test func 載入成功時填入cells與nextOffset() async throws {
        let store = makeStore(
            api: makeAPI(list: { _ in try Stub.listResponse(numbers: [1, 2, 3], nextOffset: 20) })
        )
        store.send(.onAppear)
        await store.loadTask?.value

        // 走真實映射，所以可以直接斷言編號 —— 比原本只數 count 更強
        #expect(store.viewState.cells.map(\.number) == [1, 2, 3])
        #expect(store.viewState.nextOffset == 20)
        #expect(store.viewState.isLoading == false)
        #expect(store.viewState.alert == nil)
    }

    @Test func 載入失敗時設定alert() async throws {
        let store = makeStore(api: makeAPI(list: { _ in throw PkError.badRequest }))
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(store.viewState.alert != nil)
        #expect(store.viewState.cells.isEmpty)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 已經到底時loadMore不再發請求() async throws {
        let calls = Recorder<Int>()
        let store = makeStore(
            api: makeAPI(list: { offset in
                calls.record(offset)
                return try Stub.listResponse(numbers: [1], nextOffset: nil)
            })
        )
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.nextOffset == nil)
        #expect(store.viewState.hasNextPage == false)
        #expect(calls.count == 1)

        store.send(.loadMore)
        await store.loadTask?.value

        #expect(calls.count == 1)
    }

    @Test func 收藏過濾會改變displayCells() async throws {
        let isFavorite = Recorder<Bool>()
        // 用 Recorder 當可變旗標：record 一個值代表「之後都回傳這個」
        isFavorite.record(false)
        let store = makeStore(
            api: makeAPI(list: { _ in try Stub.listResponse(numbers: [1, 2], nextOffset: 20) }),
            favorites: makeFavorites(contains: { _ in isFavorite.recorded.last ?? false })
        )
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.displayCells.map(\.number) == [1, 2])

        isFavorite.record(true)
        store.send(.tapFavorite)

        #expect(store.viewState.isFavoriteFilterOn == true)
        #expect(store.viewState.displayCells.map(\.number) == [1, 2])

        isFavorite.record(false)
        store.send(.tapFavorite)
        store.send(.tapFavorite)

        #expect(store.viewState.isFavoriteFilterOn == true)
        #expect(store.viewState.displayCells.isEmpty)
        #expect(store.viewState.isEmpty == true)
    }

    @Test func 切換版型() {
        let store = makeStore()
        #expect(store.viewState.isListLayout == true)
        store.send(.tapChangeLayout)
        #expect(store.viewState.isListLayout == false)
    }

    @Test func dismissAlert清除alert() async throws {
        let store = makeStore(api: makeAPI(list: { _ in throw PkError.badRequest }))
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        store.send(.dismissAlert)
        #expect(store.viewState.alert == nil)
    }

    /// 釘住「Store 把自己的 api 傳給了它建立的 CellViewModel」。
    ///
    /// 少了這個測試，`load()` 內漏傳 `api` 不會被任何東西抓到：cell 會退回
    /// `CellViewModel` 的預設值也就是 `Dependencies.api`（live 實作），app 照樣
    /// 正常，而 Store 的其他測試都不呼叫 `bindView()`。後果是別人的測試會安靜地
    /// 打真實網路。
    @Test func Store把自己的api傳給cell() async throws {
        let calls = Recorder<Int>()
        let store = makeStore(
            api: .init(
                list: { _ in try Stub.listResponse(numbers: [7], nextOffset: nil) },
                pokemon: { id in calls.record(id); return Stub.pokemon(id: id) },
                species: { _ in throw PkError.badRequest }
            )
        )
        store.send(.onAppear)
        await store.loadTask?.value

        let cell = try #require(store.viewState.cells.first)
        cell.bindView()
        await cell.loadTask?.value

        #expect(calls.recorded == [7])
        #expect(cell.pokemon?.id == 7)
    }

    @Test func 點選cell後把species回填() async throws {
        let cell = CellViewModel(
            source: try Stub.item(25),
            api: makeAPI()
        )
        #expect(cell.spiecs == nil)

        let store = makeStore(
            navigator: makeNavigator(showDetail: { _ in Stub.species(cnName: "皮卡丘") })
        )
        store.send(.tapCell(cell))
        await store.detailTask?.value

        #expect(cell.spiecs?.names.first?.name == "皮卡丘")
    }
}
