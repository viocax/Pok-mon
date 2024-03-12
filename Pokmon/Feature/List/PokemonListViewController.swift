//
//  PokemonListViewController.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import UIKit
import RxSwift
import RxCocoa

class PokemonListViewController: UIViewController {

    private let listFlowLayout: ListFlowLayout = .init()
    private let gridFlowLayout: GridFlowLayout = .init()
    private lazy var collectionView: UICollectionView = .init(frame: .zero, collectionViewLayout: listFlowLayout)
    private let loadMorePublisher: PublishRelay<Bool> = .init()
    private let disposeBag = DisposeBag()
    private let viewModel: PokemonListViewModel
    private let isFavoriteButton: UIButton = .init()
    private let changeLayoutButton: UIButton = .init()
    init(viewModel: PokemonListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUIAttribute()
        setupLayout()
        bindView()
    }
}

extension PokemonListViewController {
    func setupUIAttribute() {
        title = "Pokemon List"
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
        changeLayoutButton.titleLabel?.font = .systemFont(ofSize: 14)
        changeLayoutButton.setTitleColor(.black, for: .normal)
        navigationItem.setLeftBarButton(.init(customView: isFavoriteButton), animated: false)
        navigationItem.setRightBarButton(.init(customView: changeLayoutButton), animated: false)
        view.backgroundColor = .white
        collectionView.register(PokemonCell.self, forCellWithReuseIdentifier: "PokemonCell")
        collectionView.backgroundColor = .white
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
    func bindView() {
        let bindViewRelay = PublishRelay<Void>()
        defer { bindViewRelay.accept(()) }

        let viewWillAppear = rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:)))
            .map { _ in }
            .asDriver(onErrorDriveWith: .empty())
        let tapCell = collectionView.rx.modelSelected(CellViewModel.self)
            .asDriver()
        let loadMore = loadMorePublisher.distinctUntilChanged()
            .compactMap { $0 ? () : nil }
            .asDriver(onErrorDriveWith: .empty())
        let input = PokemonListViewModel
            .Input(
                changeLayout: changeLayoutButton.rx.tap.asDriver(),
                clickFavorite: isFavoriteButton.rx.tap.asDriver(),
                bindView: bindViewRelay.asDriver(onErrorDriveWith: .empty()),
                viewWillAppear: viewWillAppear,
                loadMore: loadMore,
                clickCell: tapCell
            )
        let output = viewModel.transform(input)
        output.configuration
            .drive()
            .disposed(by: disposeBag)
        output.isEmpty
            .drive(view.rx.isEmpty)
            .disposed(by: disposeBag)
        output.isFavorite
            .drive(isFavorite)
            .disposed(by: disposeBag)
        output.isLoading
            .drive(view.rx.indicatorAnimator)
            .disposed(by: disposeBag)
        output.list
            .drive(collectionView.rx.items) { collection, row, model in
                let cell = collection.dequeueReusableCell(withReuseIdentifier: "PokemonCell", for: .init(item: row, section: .zero))
                (cell as? PokemonCell)?.bindView(model)
                return cell
            }.disposed(by: disposeBag)
        output.isListOrGrid
            .drive(isList)
            .disposed(by: disposeBag)
        collectionView.rx.setDelegate(self)
            .disposed(by: disposeBag)
    }
    var isList: Binder<Bool> {
        return .init(self) { vc, isListOrGrid in
            vc.changeLayoutButton.setTitle(isListOrGrid ? "List" : "Grid", for: .normal)
            let newLayout = isListOrGrid ? vc.listFlowLayout : vc.gridFlowLayout
            if newLayout != vc.collectionView.collectionViewLayout {
                vc.collectionView.setCollectionViewLayout(newLayout, animated: true)
            }
        }
    }
    var isFavorite: Binder<Bool> {
        return Binder(self.isFavoriteButton) { button, isFavorite in
            let string = isFavorite ? "bookmark.fill" : "bookmark"
            button.setImage(.init(systemName: string), for: .normal)
        }
    }
}

// MARK: UIScrollViewDelegate
extension PokemonListViewController: UIScrollViewDelegate {
    private func detectScrollToBottomEdge(_ scrollView: UIScrollView) {
        let isScrollToBottom = scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height
        loadMorePublisher.accept(isScrollToBottom)
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
