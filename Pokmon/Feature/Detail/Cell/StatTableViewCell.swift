//
//  StatTableViewCell.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/11.
//

import UIKit

final class StatTableViewCell: UITableViewCell {
    private let titleLabel: UILabel = .init()
    private let stackView: UIStackView = .init()
    private let sumLabel: UILabel = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUIAttributes()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUIAttributes()
        setupLayout()
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        
    }
}

private extension StatTableViewCell {
    func setupUIAttributes() {
        selectionStyle = .none
        contentView.backgroundColor = .white
        titleLabel.font = .systemFont(ofSize: 18)
        titleLabel.textColor = .black
        titleLabel.text = "種族值    max:(180)"
        sumLabel.font = .systemFont(ofSize: 16)
        sumLabel.textColor = .black
        stackView.axis = .vertical
        stackView.spacing = 0
    }
    func setupLayout() {
        contentView.backgroundColor = .white
        contentView.addSubview(titleLabel)
        contentView.addSubview(sumLabel)
        contentView.addSubview(stackView)
        contentView.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            sumLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sumLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            sumLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor),
            sumLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
}

extension StatTableViewCell {
    func bindView(_ model: PokmonResponse) {
        assert(model.stats.count == 6, "check data, pokemon stats")
        let isAddNewView = stackView.arrangedSubviews.isEmpty
        if isAddNewView {
            model.stats.forEach { stat in
                let statView = StatView()
                statView.setStat(stat)
                stackView.addArrangedSubview(statView)
            }
            zip(model.stats, stackView.arrangedSubviews).forEach { stat, view in
                (view as? StatView)?.animation(stat)
            }
        } else {
            zip(model.stats, stackView.arrangedSubviews).forEach { stat, view in
                (view as? StatView)?.setStat(stat)
                (view as? StatView)?.animation(stat)
            }
        }
        let sum = model.stats.reduce(0, { $0 + $1.baseStat })
        sumLabel.text = "總和： \(sum)"
    }
}
