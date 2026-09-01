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

    private func makeStore(
        service: MockService? = nil,
        favorite: MockFavoriteUseCase = .init(),
        list: MockListUseCase = .init(),
        coordinator: MockCoordinator = .init()
    ) -> PokemonListStore {
        PokemonListStore(
            dependency: .init(
                coordinator: coordinator,
                service: service ?? MockService(),
                favorite: favorite,
                list: list
            )
        )
    }

    @Test func 載入成功時填入cells與nextOffset() async throws {
        let service = MockService()
        service.injectAsyncResponse = try Stub.listResponse(numbers: [1, 2, 3], nextOffset: 20)
        let list = MockListUseCase()
        list.injectCellViewModels = [
            CellViewModel(source: try Stub.item(1)),
            CellViewModel(source: try Stub.item(2)),
            CellViewModel(source: try Stub.item(3))
        ]
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(service: service, favorite: favorite, list: list)
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(store.viewState.cells.count == 3)
        #expect(store.viewState.nextOffset == 20)
        #expect(store.viewState.isLoading == false)
        #expect(store.viewState.alert == nil)
    }

    @Test func 載入失敗時設定alert() async throws {
        let service = MockService()
        service.injectAsyncError = PkError.badRequest

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value

        #expect(store.viewState.alert != nil)
        #expect(store.viewState.cells.isEmpty)
        #expect(store.viewState.isLoading == false)
    }

    @Test func 已經到底時loadMore不再發請求() async throws {
        let service = MockService()
        service.injectAsyncResponse = try Stub.listResponse(numbers: [1], nextOffset: nil)
        let list = MockListUseCase()
        list.injectCellViewModels = [CellViewModel(source: try Stub.item(1))]

        let store = makeStore(service: service, list: list)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.nextOffset == nil)
        #expect(store.viewState.hasNextPage == false)

        let countAfterFirstLoad = service.requestedPaths.count
        store.send(.loadMore)
        await store.loadTask?.value

        #expect(service.requestedPaths.count == countAfterFirstLoad)
    }

    @Test func 收藏過濾會改變displayCells() async throws {
        let service = MockService()
        service.injectAsyncResponse = try Stub.listResponse(numbers: [1, 2], nextOffset: 20)
        let list = MockListUseCase()
        list.injectCellViewModels = [
            CellViewModel(source: try Stub.item(1)),
            CellViewModel(source: try Stub.item(2))
        ]
        let favorite = MockFavoriteUseCase()
        favorite.injectIsContain = false

        let store = makeStore(service: service, favorite: favorite, list: list)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.displayCells.count == 2)

        favorite.injectIsContain = true
        store.send(.tapFavorite)

        #expect(store.viewState.isFavoriteFilterOn == true)
        #expect(store.viewState.displayCells.count == 2)

        favorite.injectIsContain = false
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
        let service = MockService()
        service.injectAsyncError = PkError.badRequest

        let store = makeStore(service: service)
        store.send(.onAppear)
        await store.loadTask?.value
        #expect(store.viewState.alert != nil)

        store.send(.dismissAlert)
        #expect(store.viewState.alert == nil)
    }

    @Test func 點選cell後把species回填() async throws {
        let coordinator = MockCoordinator()
        coordinator.injectShowDetailPageAsync = Stub.species(cnName: "皮卡丘")
        let cell = CellViewModel(source: try Stub.item(25))
        #expect(cell.spiecs == nil)

        let store = makeStore(coordinator: coordinator)
        store.send(.tapCell(cell))
        await store.detailTask?.value

        #expect(cell.spiecs?.names.first?.name == "皮卡丘")
    }
}
