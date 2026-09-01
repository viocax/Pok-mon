//
//  PokemonDeatilPageViewController.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import UIKit

final class PokemonDeatilPageViewController: UIViewController {

    // MARK: - Properties

    /// 離開這頁時把最新的 species 交還給推它的人。只會被呼叫一次。
    var onFinish: ((PokemonSpeciesResponse?) -> Void)?

    private let store: PokemonDetailStore
    private var presentedAlert: AlertState?
    private let tableView: UITableView = .init(frame: .zero, style: .insetGrouped)
    private lazy var dataSource = makeDataSource()

    fileprivate enum Section {
        case main
    }

    // MARK: - Life cycle

    init(store: PokemonDetailStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUIAttributes()
        setupLayout()
        bindStore()
        store.send(.onAppear)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        store.send(.viewWillDisappear)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 只有真的離開這一頁才交還,被別的畫面蓋住不算
        guard isMovingFromParent || isBeingDismissed else { return }
        store.send(.viewDidDisappear)
        finish()
    }

    deinit {
        onFinish?(nil)
    }
}

// MARK: - private

private extension PokemonDeatilPageViewController {

    func finish() {
        let handler = onFinish
        onFinish = nil
        handler?(store.viewState.species)
    }

    func makeDataSource() -> UITableViewDiffableDataSource<Section, PokemonDetailStore.Row> {
        .init(tableView: tableView) { [weak self] tableView, indexPath, row in
            guard let self else { return UITableViewCell() }
            switch row {
            case .info(let species):
                let cell = tableView.dequeueReusableCell(withIdentifier: "PokemonDetailInfoCell", for: indexPath)
                (cell as? PokemonDetailInfoCell)?.delegate = self
                (cell as? PokemonDetailInfoCell)?.bindView(
                    .init(
                        pokemon: self.store.pokemon,
                        species: species,
                        isFavorite: { [store = self.store] in store.viewState.isFavorite }
                    )
                )
                return cell

            case .stat:
                let cell = tableView.dequeueReusableCell(withIdentifier: "StatTableViewCell", for: indexPath)
                (cell as? StatTableViewCell)?.bindView(self.store.pokemon)
                return cell
            }
        }
    }

    func apply(_ rows: [PokemonDetailStore.Row]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, PokemonDetailStore.Row>()
        snapshot.appendSections([.main])
        snapshot.appendItems(rows, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func setupUIAttributes() {
        view.backgroundColor = .white
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.register(.init(nibName: "PokemonDetailInfoCell", bundle: nil), forCellReuseIdentifier: "PokemonDetailInfoCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 250
        tableView.register(StatTableViewCell.self, forCellReuseIdentifier: "StatTableViewCell")
    }

    func setupLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }

    func bindStore() {
        observe { [weak self] in
            guard let self else { return }
            self.title = self.store.viewState.title
        }

        observe { [weak self] in
            guard let self else { return }
            self.apply(self.store.viewState.rows)
        }

        observe { [weak self] in
            guard let self else { return }
            self.view.setEmpty(self.store.viewState.isEmpty)
        }

        observe { [weak self] in
            guard let self else { return }
            self.view.setLoading(self.store.viewState.isLoading)
        }

        observe { [weak self] in
            guard let self else { return }
            guard let alert = self.store.viewState.alert else {
                self.presentedAlert = nil
                return
            }
            guard self.presentedAlert != alert else { return }
            self.presentedAlert = alert
            self.presentAlert(alert) { [weak self] in self?.store.send(.dismissAlert) }
        }
    }
}

// MARK: - PokemonDetailInfoCellDelegate

extension PokemonDeatilPageViewController: PokemonDetailInfoCellDelegate {

    func clickFavoriteSelected(_ id: Int) {
        store.send(.tapFavorite(id))
    }
}
