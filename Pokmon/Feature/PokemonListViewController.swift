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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUIAttribute()
        setupLayout()
        bindView()
    }
}

extension PokemonListViewController {
    func setupUIAttribute() {
        navigationItem.setLeftBarButton(.init(systemItem: .bookmarks), animated: false)
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
        APIService.share
            .request(PokemonListEndpont())
            .map(\.results).asDriver(onErrorJustReturn: [])
            .drive(tableView.rx.items) { tableView, row, model in
                let cell = tableView.dequeueReusableCell(withIdentifier: "PokemonCell", for: .init(row: row, section: .zero))
//                (cell as? PokemonCell)?.bindView(<#CellViewModel#>)
                return cell
            }.disposed(by: disposeBag)
        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
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
