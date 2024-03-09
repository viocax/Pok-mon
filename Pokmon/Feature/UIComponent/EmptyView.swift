//
//  EmptyView.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import UIKit
import RxSwift
import RxCocoa

class EmptyView: UIView {
    private let imageView: UIImageView = .init(image: .init(named: "empty"))
    private let label: UILabel = .init()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUIAttributes()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUIAttributes()
        setupLayout()
    }

    func setupUIAttributes() {
        backgroundColor = .white
        
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        label.text = "空空如也"
        label.textColor = .black
        label.font = .systemFont(ofSize: 24, weight: .semibold)
        label.textAlignment = .center
    }
    func setupLayout() {
        
        addSubview(imageView)
        addSubview(label)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 100),
            imageView.heightAnchor.constraint(equalToConstant: 100),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
        ])
    }
}

extension Reactive where Base: UIView {
    var isEmpty: Binder<Bool> {
        return Binder(self.base) { targetView, isEmpty in
            let emptyView = targetView.subviews.first(where: { $0 is EmptyView })
            if isEmpty {
                if emptyView == nil {
                    let addedView = EmptyView()
                    targetView.addSubview(addedView)
                    addedView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        addedView.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
                        addedView.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
                        addedView.topAnchor.constraint(equalTo: targetView.topAnchor),
                        addedView.bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
                    ])
                }
            } else {
                emptyView?.removeFromSuperview()
            }
        }
    }
}
