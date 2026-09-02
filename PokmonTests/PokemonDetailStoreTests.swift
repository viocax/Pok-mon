//
//  PokemonDetailStoreTests.swift
//  PokmonTests
//
//  Created by drake on 2026/8/31.
//

import Testing
@testable import Pokmon

@MainActor
@Suite struct PokemonDetailStoreTests {

    /// 未指定的 closure 給明確拋錯的實作，誤呼叫時測試會紅而不是靜默通過。
    private func makeAPI(
        species: @escaping @Sendable (Int) async throws -> PokemonSpeciesResponse = { _ in
            throw PkError.badRequest
        }
    ) -> PokemonAPIClient {
        .init(
            list: { _ in throw PkError.badRequest },
            pokemon: { _ in throw PkError.badRequest },
            species: species
        )
    }

    private func makeFavorites(
        contains: @escaping @Sendable (Int) -> Bool = { _ in false },
        add: @escaping @Sendable (Int) -> Void = { _ in },
        remove: @escaping @Sendable (Int) -> Void = { _ in },
        synchronize: @escaping @Sendable () -> Void = { }
    ) -> FavoritesClient {
        .init(contains: contains, add: add, remove: remove, synchronize: synchronize)
    }

    private func makeStore(
        species: PokemonSpeciesResponse? = nil,
        api: PokemonAPIClient? = nil,
        favorites: FavoritesClient? = nil
    ) -> PokemonDetailStore {
        PokemonDetailStore(
            pokemon: Stub.pokemon(id: 1),
            species: species,
            api: api ?? makeAPI(),
            favorites: favorites ?? makeFavorites()
        )
    }

    @Test func 初始化時帶入標題與收藏狀態() {
        let store = makeStore(favorites: makeFavorites(contains: { _ in true }))

        #expect(store.viewState.title == "No.1")
        #expect(store.viewState.isFavorite == true)
    }

    @Test func species已存在時onAppear不發請求() async {
        let calls = Recorder<Int>()
        let store = makeStore(
            species: Stub.species(),
            api: makeAPI(species: { id in calls.record(id); return Stub.species() })
        )

        store.send(.onAppear)
        await store.loadTask?.value

        #expect(calls.recorded.isEmpty)
        #expect(store.viewState.isEmpty == false)
    }

    @Test func species不存在時onAppear發請求並填入() async {
        let calls = Recorder<Int>()
        let store = makeStore(
            api: makeAPI(species: { id in calls.record(id); return Stub.species() })
        )
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(calls.recorded == [1])
        #expect(store.viewState.species != nil)
        #expect(store.viewState.rows.count == 2)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 載入失敗時設定alert且dismiss會重試() async {
        let shouldFail = Recorder<Bool>()
        shouldFail.record(true)
        let store = makeStore(api: makeAPI(species: { _ in
            if shouldFail.recorded.last == true { throw PkError.badRequest }
            return Stub.species()
        }))

        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        shouldFail.record(false)
        store.send(.dismissAlert)
        await store.loadTask?.value

        #expect(store.viewState.alert == nil)
        #expect(store.viewState.species != nil)
    }

    @Test func 未收藏時點擊會新增() {
        let added = Recorder<Int>()
        let removed = Recorder<Int>()
        let store = makeStore(favorites: makeFavorites(
            contains: { _ in false },
            add: { added.record($0) },
            remove: { removed.record($0) }
        ))
        #expect(store.viewState.isFavorite == false)

        store.send(.tapFavorite(1))

        #expect(added.recorded == [1])
        #expect(removed.recorded.isEmpty)
    }

    @Test func 已收藏時點擊會移除() {
        let added = Recorder<Int>()
        let removed = Recorder<Int>()
        let store = makeStore(favorites: makeFavorites(
            contains: { _ in true },
            add: { added.record($0) },
            remove: { removed.record($0) }
        ))
        #expect(store.viewState.isFavorite == true)

        store.send(.tapFavorite(1))

        #expect(removed.recorded == [1])
        #expect(added.recorded.isEmpty)
    }

    /// 釘住「依儲存決定方向，而不是依畫面上的快取狀態」。
    /// 少了這個情境，把 toggleFavorite 改成看 viewState.isFavorite 也不會被抓到。
    @Test func 儲存與畫面狀態分歧時依儲存決定方向() {
        let contains = Recorder<Bool>()
        contains.record(false)
        let added = Recorder<Int>()
        let removed = Recorder<Int>()
        let store = makeStore(favorites: makeFavorites(
            contains: { _ in contains.recorded.last ?? false },
            add: { added.record($0) },
            remove: { removed.record($0) }
        ))
        #expect(store.viewState.isFavorite == false)

        // 製造分歧：畫面說未收藏，儲存說已收藏
        contains.record(true)
        store.send(.tapFavorite(1))

        #expect(removed.recorded == [1])
        #expect(added.recorded.isEmpty)
    }

    @Test func viewWillDisappear觸發synchronize() {
        let synced = Recorder<Bool>()
        let store = makeStore(favorites: makeFavorites(synchronize: { synced.record(true) }))

        store.send(.viewWillDisappear)

        #expect(synced.count == 1)
    }
}
