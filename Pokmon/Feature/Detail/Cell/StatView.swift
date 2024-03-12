//
//  StatView.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/10.
//

import UIKit

final class StatView: UIView {
    private let titleLabel: UILabel = .init()
    private let valueLabel: UILabel = .init()
    private let progressBar: UIProgressView = .init(progressViewStyle: .default)

    private var padding: CGFloat {
        return 8
    }
    private var labelHeight: CGFloat {
        return 28
    }
    override var intrinsicContentSize: CGSize {
        return .init(width: super.intrinsicContentSize.width, height: labelHeight)
    }

    override init(frame: CGRect) {
        super.init(frame: .zero)
        setupUIAttributes()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUIAttributes()
        setupLayout()
    }
}

private extension StatView {
    func setupUIAttributes() {
        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor  = .black
        valueLabel.textColor = .black
        valueLabel.font = .systemFont(ofSize: 14)
        progressBar.progressTintColor = .gray
    }
    func setupLayout() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(progressBar)
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 40),
            
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            valueLabel.widthAnchor.constraint(equalToConstant: 50),

            progressBar.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            progressBar.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: padding),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor)
            
        ])
    }
}

extension StatView {
    func setStat(_ stat: PokmonResponse.Stat) {
        titleLabel.text = stat.title
        valueLabel.text = "\(stat.baseStat)"
        
        
        progressBar.progressTintColor = stat.color
    }
    func animation(_ stat: PokmonResponse.Stat) {
        let progress = Float(stat.baseStat) / 180
        progressBar.setProgress(progress, animated: true)
    }
}
