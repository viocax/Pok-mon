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

    private let tableView: UITableView = .init(frame: .zero, style: .insetGrouped)
    private let loadMorePublisher: PublishRelay<Bool> = .init()
    private let disposeBag = DisposeBag()
    private let viewModel: PokemonListViewModel
    private let isFavoriteButton: UIButton = .init()
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
        isFavoriteButton.setImage(.init(systemName: "bookmark"), for: .normal)
        navigationItem.setLeftBarButton(.init(customView: isFavoriteButton), animated: false)
        view.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 80
        tableView.register(PokemonCell.self, forCellReuseIdentifier: "PokemonCell")
        tableView.backgroundColor = .white
    }
    func setupLayout() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }
    func bindView() {
        let bindViewRelay = PublishRelay<Void>()
        defer { bindViewRelay.accept(()) }

        let tapCell = tableView.rx.modelSelected(CellViewModel.self)
            .asDriver()
        let input = PokemonListViewModel
            .Input(
                clickFavorite: isFavoriteButton.rx.tap.asDriver(),
                bindView: bindViewRelay.asDriver(onErrorDriveWith: .empty()),
                loadMore: loadMorePublisher.asDriver(onErrorDriveWith: .empty()),
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
            .drive(tableView.rx.items) { tableView, row, model in
                let cell = tableView.dequeueReusableCell(withIdentifier: "PokemonCell", for: .init(row: row, section: .zero))
                (cell as? PokemonCell)?.bindView(model)
                return cell
            }.disposed(by: disposeBag)
        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
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
