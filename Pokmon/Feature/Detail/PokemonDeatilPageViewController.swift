//
//  PokemonDeatilPageViewController.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import UIKit
import RxSwift
import RxCocoa

final class PokemonDeatilPageViewController: UIViewController {

    private let tableView: UITableView = .init(frame: .zero, style: .insetGrouped)
    private let disposeBag: DisposeBag = .init()
    private let favoriteRelay: PublishRelay<Int> = .init()
    private let subject: PublishRelay<PokemonSpeciesResponse?> = .init()
    public var newResponse: Observable<PokemonSpeciesResponse?> {
        let deinitVc = rx.deallocated
            .withLatestFrom(subject.asObservable())
        return Observable
            .merge(
                subject.asObservable(),
                deinitVc
            ).catch { _ in .empty() }
            .take(1)
    }
    private let viewModel: PokemonDeatilPageViewModel
    init(viewModel: PokemonDeatilPageViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUIAttributes()
        setupLayout()
        bindView()
    }
}

// MARK: - private
private extension PokemonDeatilPageViewController {
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
    func bindView() {
        let bindViewRelay = PublishRelay<Void>()
        defer { bindViewRelay.accept(()) }

        let input = PokemonDeatilPageViewModel
            .Input(
                bindView: bindViewRelay.asDriver(onErrorDriveWith: .empty()),
                isFavorite: favoriteRelay.asDriver(onErrorDriveWith: .empty())
            )
        let output = viewModel.transform(input)
        output.configuration
            .drive()
            .disposed(by: disposeBag)
        output.list
            .drive(tableView.rx.items) { tableView, row, model in
                switch model {
                case let .info(info):
                    let cell = tableView.dequeueReusableCell(withIdentifier: "PokemonDetailInfoCell", for: .init(row: row, section: .zero))
                    (cell as? PokemonDetailInfoCell)?.delegate = self
                    (cell as? PokemonDetailInfoCell)?.bindView(info)
                    return cell
                case .stat(let pokemon):
                    let cell = tableView.dequeueReusableCell(withIdentifier: "StatTableViewCell", for: .init(row: row, section: .zero))
                    (cell as? StatTableViewCell)?.bindView(pokemon)
                    return cell
                default:
                    return UITableViewCell()
                }

            }.disposed(by: disposeBag)
        output.isEmpty
            .drive(view.rx.isEmpty)
            .disposed(by: disposeBag)
        output.isLoading
            .drive(view.rx.indicatorAnimator)
            .disposed(by: disposeBag)
        output.spiecs
            .drive(onNext: subject.accept(_:))
            .disposed(by: disposeBag)
        output.title
            .drive(onNext: { [weak self] title in
                self?.title = title
            })
            .disposed(by: disposeBag)
    }
}

extension PokemonDeatilPageViewController: PokemonDetailInfoCellDelegate {
    func clickFavoriteSelected(_ id: Int) {
        favoriteRelay.accept(id)
    }
}
