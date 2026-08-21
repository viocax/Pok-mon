//
//  PokemonListViewControllerV2.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//
//  Spike:PokemonListViewController 的 Concurrency 版。
//  UI 佈局照抄舊檔案,差別只在資料流 — 用 Combine 訂閱 store.$viewState,
//  事件用 store.send(.xxx) 送回去。Cell 內部維持 Rx,驗證新舊共存。
//

import Combine
import RxCocoa
import UIKit

final class PokemonListViewControllerV2: UIViewController {

    // MARK: - Properties

    private let store: PokemonListStore
    private var cancellables: Set<AnyCancellable> = .init()

    private let listFlowLayout: PokemonListViewController.ListFlowLayout = .init()
    private let gridFlowLayout: PokemonListViewController.GridFlowLayout = .init()
    private lazy var collectionView: UICollectionView = .init(frame: .zero, collectionViewLayout: listFlowLayout)
    private let isFavoriteButton: UIButton = .init()
    private let changeLayoutButton: UIButton = .init()

    /// 畫面目前實際渲染的資料,dataSource 從這裡讀,避免 reloadData 與 state 不同步
    private var cells: [CellViewModel] = []
    private var isScrollToBottom = false

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

private extension PokemonListViewControllerV2 {

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
        collectionView.register(PokemonCell.self, forCellWithReuseIdentifier: "PokemonCell")
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
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

    /// 舊版是六條 Driver 各自 drive;現在是一條 State 用 map + removeDuplicates 拆成六條。
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
                // 既有的 Rx Binder 可以直接當 ObserverType 用,不用為了搬家重寫 UI 程式
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
            .sink { [weak self] cells in
                self?.cells = cells
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)

        state
            .compactMap(\.alert)
            .removeDuplicates()
            .sink { [weak self] alert in self?.presentAlert(alert) }
            .store(in: &cancellables)
    }

    func applyLayout(isList: Bool) {
        changeLayoutButton.setTitle(isList ? "List" : "Grid", for: .normal)
        let newLayout = isList ? listFlowLayout : gridFlowLayout
        if newLayout != collectionView.collectionViewLayout {
            collectionView.setCollectionViewLayout(newLayout, animated: true)
        }
    }

    func presentAlert(_ alert: AlertState) {
        let controller = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
        controller.addAction(.init(title: "ok", style: .default) { [weak self] _ in
            self?.store.send(.dismissAlert)
        })
        present(controller, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension PokemonListViewControllerV2: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cells.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PokemonCell", for: indexPath)
        (cell as? PokemonCell)?.bindView(cells[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension PokemonListViewControllerV2: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        store.send(.tapCell(cells[indexPath.item]))
    }

    private func detectScrollToBottomEdge(_ scrollView: UIScrollView) {
        let isBottom = scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height
        // 取代 distinctUntilChanged:只有從「不在底部」變成「在底部」才觸發
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
