//
//  PokemonDeatilPageViewController.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import UIKit

final class PokemonDeatilPageViewController: UIViewController {

    private let tableView: UITableView = .init(frame: .zero, style: .insetGrouped)
    
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
        
    }
}
