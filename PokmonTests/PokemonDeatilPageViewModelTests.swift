//
//  PokemonDeatilPageViewModelTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import XCTest
import RxSwift
import RxTest
import RxRelay
@testable import Pokmon

final class PokemonDeatilPageViewModelTests: XCTestCase {

    var disposeBag = DisposeBag()
    var viewModel: PokemonDeatilPageViewModel!
    let mockUsecase = MockFavoriteUseCase()
    let mockService = MockService()
    let mockSpiecs = PokemonSpeciesResponse(color: .init(name: "fakename", url: "fakeURL"), flavorEntitys: [], names: [])
    let expectNumber = 3
    var expectThumbnail: String {
        return "https://pokeapi.co/api/v2/pokemon.png"
    }

    override func setUp() {
        super.setUp()
        disposeBag = .init()
        

     
        let mockPokemon = PokmonResponse(id: expectNumber, name: "name", height: 111, weight: 22, sprites: .init(thumbnail: expectThumbnail), species: .init(name: "TestName", url: "TestName"), types: [], stats: [])
        

        let mockCoordinator = MockCoordinator()
        mockCoordinator.injectShowAlert = .just(())
        mockUsecase.injectIsContain = true

        
        mockService.injectRequest = .just(mockSpiecs)

        let dependency = PokemonDeatilPageViewModel
            .Dependency(spiecs: nil, pokemon: mockPokemon, coordinator: mockCoordinator)


        dependency.mock(dependency: mockUsecase, FavoriteUseCase.self)
        dependency.mock(dependency: mockService, NetworkService.self)
        viewModel = .init(dependency: dependency)

    }
    func test_viewModel() {
        let testScheduler = TestScheduler(initialClock: .zero)

        let bindView = testScheduler.createColdObservable([
            .next(0, ()),
            .next(10, ())
        ])
        let click = testScheduler.createColdObservable([
            .next(20, expectNumber),
            .next(30, expectNumber)
        ])
        let willDisappear = testScheduler.createColdObservable([
            .next(40, ())
        ])
        let input = PokemonDeatilPageViewModel
            .Input(
                bindView: bindView.asDriver(onErrorDriveWith: .never()),
                isFavorite: click.asDriver(onErrorDriveWith: .never()),
                viewWillDisappear: willDisappear.asDriver(onErrorDriveWith: .never())
            )

        let output = viewModel.transform(input)
        
        let observeTitle = testScheduler.createObserver(String.self)
        output.title
            .drive(observeTitle)
            .disposed(by: disposeBag)

        let observerConfig = testScheduler.createObserver(Void.self)
        output.configuration
            .drive(observerConfig)
            .disposed(by: disposeBag)

        let observerLoading = testScheduler.createObserver(Bool.self)
        output.isLoading
            .drive(observerLoading)
            .disposed(by: disposeBag)
        let observerIsEmpty = testScheduler.createObserver(Bool.self)
        output.isEmpty
            .drive(observerIsEmpty)
            .disposed(by: disposeBag)
        let observeSpies = testScheduler.createObserver(PokemonSpeciesResponse.self)
        output.spiecs
            .drive(observeSpies)
            .disposed(by: disposeBag)
        let observeList = testScheduler.createObserver([PokemonDeatilPageViewModel.CellDisplayModel].self)
        output.list
            .drive(observeList)
            .disposed(by: disposeBag)
        
        testScheduler.scheduleAt(25) {
            self.mockService.injectRequest = .error(PkError.pokemonDataNotYet)
            self.mockUsecase.injectIsContain = false
        }

        testScheduler.start()


        XCTAssertEqual(mockUsecase.recordIsContain, 3)
        XCTAssertEqual(mockUsecase.recordInsert, 1)
        XCTAssertEqual(mockUsecase.recordRemove, 1)
        XCTAssertEqual(mockUsecase.recordSynchronize, 1)
        XCTAssertEqual(observeTitle.events, [
            .next(0, "No.\(expectNumber)"),
            .next(10, "No.\(expectNumber)")
        ])
        XCTAssertEqual(observerLoading.events, [
            .next(0, false),
            .next(0, true),
            .next(0, false),
            .next(10, true),
            .next(10, false)
        ])
        XCTAssertEqual(observerIsEmpty.events, [
            .next(0, false),
            .next(10, false)
        ])
        XCTAssertEqual(observeSpies.events, [
            .next(0, mockSpiecs),
            .next(10, mockSpiecs)
        ])

        XCTAssertEqual(observerConfig.events.map(\.time), [
            20, 30, 40
        ])
        XCTAssertEqual(observeList.events.map(\.time), [
            0, 10
        ])
    }
}
