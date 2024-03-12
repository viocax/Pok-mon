//
//  CellViewModelTests.swift
//  PokmonTests
//
//  Created by drake on 2024/3/12.
//

import XCTest
import RxSwift
import RxTest
import RxRelay
@testable import Pokmon

final class CellViewModelTests: XCTestCase {

    
    var disposeBag = DisposeBag()
    var viewModel: CellViewModel!
    var expectName: String {
        return "testNamePokeMon"
    }
    var expectThumbnail: String {
        return "https://pokeapi.co/api/v2/pokemon.png"
    }
    let expectNumber = 3
    
    override func setUp() {
        super.setUp()
        disposeBag = .init()
        // Mock dependency
        let mockNetworkService = MockService()
        
        let mockSource = try! PokemonListResponse.Item(.init(name: "mockName", url: "https://pokeapi.co/api/v2/pokemon/\(expectNumber)"))
        let mockDependency = CellViewModel.Dependency(source: mockSource)
        mockDependency.mock(dependency: mockNetworkService, NetworkService.self)

        let mockPokemon = PokmonResponse(id: expectNumber, name: expectName, height: 111, weight: 22, sprites: .init(thumbnail: expectThumbnail), species: .init(name: "TestName", url: "TestName"), types: [], stats: [])

        mockNetworkService.injectRequest = .just(mockPokemon)

        viewModel = CellViewModel(dependency: mockDependency)
    }
 
    func test_cellViewModel() {
        let testScheduler = TestScheduler(initialClock: .zero)

        let bindView = testScheduler.createColdObservable([
            .next(100, ())
        ])


        let input = CellViewModel
            .Input(bindView: bindView.asDriver(onErrorDriveWith: .empty()))

        let output = viewModel.transform(input)

        let observerNumber = testScheduler.createObserver(String.self)
        output.number
            .drive(observerNumber)
            .disposed(by: disposeBag)
        let observerName = testScheduler.createObserver(String.self)
        output.name
            .drive(observerName)
            .disposed(by: disposeBag)
        let observerImageURL = testScheduler.createObserver(String.self)
        output.imageURL
            .drive(observerImageURL)
            .disposed(by: disposeBag)
        let observerTypes = testScheduler.createObserver([TypeCornerProtocol].self)
        output.types
            .drive(observerTypes)
            .disposed(by: disposeBag)


        testScheduler.start()

        XCTAssertEqual(observerName.events, [
            .next(100, "Loading..."),
            .next(100, expectName)
        ])

        XCTAssertEqual(observerNumber.events, [
            .next(100, "No.\(expectNumber)")
        ])
        XCTAssertEqual(observerImageURL.events, [
            .next(100, expectThumbnail)
        ])
        observerTypes.events.forEach { record in
            XCTAssertEqual(record.time, 100)
            XCTAssertTrue(record.value.element!.isEmpty)
        }
    }
    func test_viewModel_PokemonShareData() {
        
        do {
            let _ = try viewModel.getPokemon()
        } catch {
            switch error as? PkError {
            case .pokemonDataNotYet:
                XCTAssertTrue(true)
            default:
                XCTFail()
            }
        }
        let mockSource = try! PokemonListResponse.Item(.init(name: "mockName", url: "https://pokeapi.co/api/v2/pokemon/\(expectNumber)"))
        let mockPokemon = PokmonResponse(id: expectNumber, name: expectName, height: 111, weight: 22, sprites: .init(thumbnail: expectThumbnail), species: .init(name: "TestName", url: "TestName"), types: [], stats: [])
        viewModel = .init(dependency: .init(sepies: nil, pokemon: mockPokemon, source: mockSource))
        do {
            let model = try viewModel.getPokemon()
            XCTAssertEqual(model.id, mockPokemon.id)
        } catch {
            XCTFail(error.localizedDescription + ", test fail")
        }
        XCTAssertNil(viewModel.spiecs)
        XCTAssertEqual(viewModel.number, expectNumber)
    }
}
