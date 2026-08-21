//
//  PokemonListViewController.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Combine
import RxCocoa
import UIKit

final class PokemonListViewController: UIViewController {

    // MARK: - Properties

    private let store: PokemonListStore
    private var cancellables: Set<AnyCancellable> = .init()

    private let listFlowLayout: PokemonListViewController.ListFlowLayout = .init()
    private let gridFlowLayout: PokemonListViewController.GridFlowLayout = .init()
    private lazy var collectionView: UICollectionView = .init(frame: .zero, collectionViewLayout: listFlowLayout)
    private let isFavoriteButton: UIButton = .init()
    private let changeLayoutButton: UIButton = .init()

    private lazy var dataSource = makeDataSource()
    private var isScrollToBottom = false

    fileprivate enum Section {
        case main
    }

    // MARK: - Life cycle

    init(store: PokemonListStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUIAttribute()
        setupLayout()
        bindStore()
        store.send(.onAppear)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.send(.viewWillAppear)
    }
}

// MARK: - Setup

private extension PokemonListViewController {

    func setupUIAttribute() {
        title = "Pokemon List (async)"
        let apperance = UINavigationBarAppearance()
        apperance.configureWithOpaqueBackground()
        apperance.backgroundColor = .white
        apperance.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 18)
        ]
        navigationController?.navigationBar.standardAppearance = apperance
        navigationController?.navigationBar.scrollEdgeAppearance = apperance
        navigationController?.navigationBar.compactAppearance = apperance

        isFavoriteButton.setImage(.init(systemName: "bookmark"), for: .normal)
        isFavoriteButton.addAction(
            .init { [weak self] _ in self?.store.send(.tapFavorite) },
            for: .touchUpInside
        )
        changeLayoutButton.titleLabel?.font = .systemFont(ofSize: 14)
        changeLayoutButton.setTitleColor(.black, for: .normal)
        changeLayoutButton.addAction(
            .init { [weak self] _ in self?.store.send(.tapChangeLayout) },
            for: .touchUpInside
        )
        navigationItem.setLeftBarButton(.init(customView: isFavoriteButton), animated: false)
        navigationItem.setRightBarButton(.init(customView: changeLayoutButton), animated: false)

        view.backgroundColor = .white
        collectionView.backgroundColor = .white
        collectionView.delegate = self
    }

    func setupLayout() {
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }

    func bindStore() {
        let state = store.$viewState

        state
            .map(\.isListLayout)
            .removeDuplicates()
            .sink { [weak self] in self?.applyLayout(isList: $0) }
            .store(in: &cancellables)

        state
            .map(\.isFavoriteFilterOn)
            .removeDuplicates()
            .sink { [weak self] isOn in
                self?.isFavoriteButton.setImage(.init(systemName: isOn ? "bookmark.fill" : "bookmark"), for: .normal)
            }
            .store(in: &cancellables)

        state
            .map(\.isLoading)
            .removeDuplicates()
            .sink { [weak self] isLoading in
                guard let self else { return }
                self.view.rx.indicatorAnimator.on(.next(isLoading))
            }
            .store(in: &cancellables)

        state
            .map(\.isEmpty)
            .removeDuplicates()
            .sink { [weak self] isEmpty in
                guard let self else { return }
                self.view.rx.isEmpty.on(.next(isEmpty))
            }
            .store(in: &cancellables)

        state
            .map(\.displayCells)
            .removeDuplicates()
            .sink { [weak self] cells in self?.apply(cells) }
            .store(in: &cancellables)

        state
            .compactMap(\.alert)
            .removeDuplicates()
            .sink { [weak self] alert in
                self?.presentAlert(alert) { [weak self] in self?.store.send(.dismissAlert) }
            }
            .store(in: &cancellables)
    }

    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, CellViewModel> {
        let registration = UICollectionView.CellRegistration<PokemonCell, CellViewModel> { cell, _, model in
            cell.bindView(model)
        }
        return .init(collectionView: collectionView) { collectionView, indexPath, model in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: model)
        }
    }

    func apply(_ cells: [CellViewModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, CellViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(cells, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func applyLayout(isList: Bool) {
        changeLayoutButton.setTitle(isList ? "List" : "Grid", for: .normal)
        let newLayout = isList ? listFlowLayout : gridFlowLayout
        if newLayout != collectionView.collectionViewLayout {
            collectionView.setCollectionViewLayout(newLayout, animated: true)
        }
    }
}

// MARK: - UICollectionViewDelegate

extension PokemonListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let model = dataSource.itemIdentifier(for: indexPath) else { return }
        store.send(.tapCell(model))
    }

    private func detectScrollToBottomEdge(_ scrollView: UIScrollView) {
        let isBottom = scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height
        guard isBottom != isScrollToBottom else { return }
        isScrollToBottom = isBottom
        if isBottom {
            store.send(.loadMore)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        detectScrollToBottomEdge(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        detectScrollToBottomEdge(scrollView)
    }
}

extension PokemonListViewController {
    class ListFlowLayout: UICollectionViewFlowLayout {
        override init() {
            super.init()
            minimumLineSpacing = 8
            minimumInteritemSpacing = 8
            let length = (UIScreen.main.bounds.width - 48)
            itemSize = .init(width: length, height: 104)
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    class GridFlowLayout: UICollectionViewFlowLayout {
        override init() {
            super.init()
            sectionInset = .init(top: 8, left: 8, bottom: 8, right: 8)
            minimumLineSpacing = 8
            minimumInteritemSpacing = 8

            let length = (UIScreen.main.bounds.width - 24) / 2
           
            itemSize = .init(width: length, height: length)
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
