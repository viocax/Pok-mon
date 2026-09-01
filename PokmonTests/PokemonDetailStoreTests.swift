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

    private func makeStore(
        spiecs: PokemonSpeciesResponse? = nil,
        service: MockService? = nil,
        favorite: MockFavoriteUseCase = .init()
    ) -> PokemonDetailStore {
        PokemonDetailStore(
            dependency: .init(
                spiecs: spiecs,
                pokemon: Stub.pokemon(id: 1),
                service: service ?? MockService(),
                favorite: favorite
            )
        )
    }

    @Test func 初始化時帶入標題與收藏狀態() {
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = true

        let store = makeStore(favorite: favorite)

        #expect(store.viewState.title == "No.1")
        #expect(store.viewState.isFavorite == true)
    }

    @Test func species已存在時onAppear不發請求() async {
        let service = MockService()
        let store = makeStore(spiecs: Stub.species(), service: service)

        store.send(.onAppear)
        await store.loadTask?.value

        #expect(service.requestedPaths.isEmpty)
        #expect(store.viewState.isEmpty == false)
    }

    @Test func species不存在時onAppear發請求並填入() async {
        let service = MockService()
        service.injectAsyncResponse = Stub.species()

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(service.requestedPaths == ["pokemon-species/1"])
        #expect(store.viewState.species != nil)
        #expect(store.viewState.rows.count == 2)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 載入失敗時設定alert且dismiss會重試() async {
        let service = MockService()
        service.injectAsyncError = PkError.badRequest

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        service.injectAsyncError = nil
        service.injectAsyncResponse = Stub.species()
        store.send(.dismissAlert)
        await store.loadTask?.value

        #expect(store.viewState.alert == nil)
        #expect(store.viewState.species != nil)
    }

    @Test func 未收藏時點擊會新增() {
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(favorite: favorite)
        #expect(store.viewState.isFavorite == false)

        store.send(.tapFavorite(1))

        #expect(favorite.recordInsert == 1)
        #expect(favorite.recordRemove == 0)
    }

    @Test func 已收藏時點擊會移除() {
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = true

        let store = makeStore(favorite: favorite)
        #expect(store.viewState.isFavorite == true)

        store.send(.tapFavorite(1))

        #expect(favorite.recordRemove == 1)
        #expect(favorite.recordInsert == 0)
    }

    /// 釘住「依儲存決定方向，而不是依畫面上的快取狀態」。
    /// 少了這個情境，把 toggleFavorite 改成看 viewState.isFavorite 也不會被抓到。
    @Test func 儲存與畫面狀態分歧時依儲存決定方向() {
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(favorite: favorite)
        #expect(store.viewState.isFavorite == false)

        // 製造分歧：畫面說未收藏，儲存說已收藏
        favorite.injectIsContain = true
        store.send(.tapFavorite(1))

        #expect(favorite.recordRemove == 1)
        #expect(favorite.recordInsert == 0)
    }

    @Test func viewWillDisappear觸發synchronize() {
        let favorite = MockFavoriteUseCase()
        let store = makeStore(favorite: favorite)

        store.send(.viewWillDisappear)

        #expect(favorite.recordSynchronize == 1)
    }
}
