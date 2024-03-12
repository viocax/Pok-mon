//
//  PokemonListViewModelTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import XCTest
import RxSwift
import RxTest
import RxRelay
@testable import Pokmon

final class PokemonListViewModelTests: XCTestCase {

    var disposeBag = DisposeBag()
    var viewModel: PokemonListViewModel!
    let mockService = MockService()
    let mockUsecase = MockFavoriteUseCase()
    let mockListUseCase = MockListUseCase()
    var mockResponse: PokemonListResponse!
    var mockCellViewodel: CellViewModel!

    override func setUp() {
        super.setUp()

        let mockCoordinator = MockCoordinator()
        let dependency = PokemonListViewModel.Dependency(coordinator: mockCoordinator)
        viewModel = .init(dependency: dependency)
        dependency.mock(dependency: mockService, NetworkService.self)
        dependency.mock(dependency: mockUsecase, FavoriteUseCase.self)
        dependency.mock(dependency: mockListUseCase, ListUsecase.self)

        let item: [PokemonListResponse.Item] = [try! .init(.init(name: "3", url: "https://pokeapi.co/api/v2/pokemon/3"))]

        mockResponse = .init(results: item, offset: 20, totalCount: 20)
        mockService.injectRequest = .just(mockResponse!)
        mockListUseCase.injectCellViewModels = item.map({ item in
            let mockDependency = CellViewModel.Dependency(source: item)
            let cellViewModel = CellViewModel(dependency: mockDependency)
            mockDependency.mock(dependency: mockService, NetworkService.self)
            return cellViewModel
        })

        mockUsecase.injectIsContain = true

        mockCellViewodel = mockListUseCase.injectCellViewModels.first
    }
    func test_viewModel() {
        let testScheduler = TestScheduler(initialClock: .zero)

        let bindView = testScheduler.createColdObservable([
            .next(0, ())
        ])
        let viewWillAppear = testScheduler.createColdObservable([
            .next(5, ())
        ])

        let clickFavorite = testScheduler.createColdObservable([
            .next(30, ()),
            .next(40, ())
        ])
        let changeLayout = testScheduler.createColdObservable([
            .next(50, ()),
            .next(60, ())
        ])
        let loadMore = testScheduler.createColdObservable([
            .next(70, ())
        ])
        let clickCell = testScheduler.createColdObservable([
            .next(80, mockCellViewodel!)
        ])

        let input = PokemonListViewModel
            .Input(
                changeLayout: changeLayout.asDriver(onErrorDriveWith: .never()),
                clickFavorite: clickFavorite.asDriver(onErrorDriveWith: .never()),
                bindView: bindView.asDriver(onErrorDriveWith: .never()),
                viewWillAppear: viewWillAppear.asDriver(onErrorDriveWith: .never()),
                loadMore: loadMore.asDriver(onErrorDriveWith: .never()),
                clickCell: clickCell.asDriver(onErrorDriveWith: .never())
            )
        let output = viewModel.transform(input)

        let observeIsFavorite = testScheduler.createObserver(Bool.self)
        output.isFavorite
            .drive(observeIsFavorite)
            .disposed(by: disposeBag)
        let observeIsLoading = testScheduler.createObserver(Bool.self)
        output.isLoading
            .drive(observeIsLoading)
            .disposed(by: disposeBag)
        let observeConfig = testScheduler.createObserver(Void.self)
        output.configuration
            .drive(observeConfig)
            .disposed(by: disposeBag)
        let observeIsEmpty = testScheduler.createObserver(Bool.self)
        output.isEmpty
            .drive(observeIsEmpty)
            .disposed(by: disposeBag)
        let observeIsList = testScheduler.createObserver(Bool.self)
        output.isListOrGrid
            .drive(observeIsList)
            .disposed(by: disposeBag)
        let observeList = testScheduler.createObserver([CellViewModel].self)
        output.list
            .drive(observeList)
            .disposed(by: disposeBag)

        testScheduler.start()

        XCTAssertEqual(observeIsFavorite.events, [
            .next(0, false),
            .next(30, true),
            .next(40, false)
        ])
        XCTAssertEqual(observeIsLoading.events, [
            .next(0, false),
            .next(0, true),
            .next(0, false),
            .next(70, true),
            .next(70, false)
        ])
        XCTAssertEqual(observeConfig.events.map(\.time), [
            0, 70
        ])
        XCTAssertEqual(observeIsEmpty.events, [
            .next(0, true),
            .next(0, false)
        ])
        XCTAssertEqual(observeIsList.events, [
            .next(0, true),
            .next(50, false),
            .next(60, true)
        ])
        XCTAssertEqual(observeList.events, [
            .next(0, []),
            .next(0, []),
            .next(0, mockListUseCase.injectCellViewModels),
            .next(5, mockListUseCase.injectCellViewModels),
            .next(30, mockListUseCase.injectCellViewModels),
            .next(40, mockListUseCase.injectCellViewModels),
            .next(70, mockListUseCase.injectCellViewModels + mockListUseCase.injectCellViewModels)
        ])
    }
}
