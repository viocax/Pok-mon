//
//  IndicatorView.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import RxSwift
import UIKit

class IndicatorView: UIView {
    private let blurView: UIView = .init()
    private let indicatorView: UIActivityIndicatorView = .init(style: .medium)

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
    private func setupUIAttributes() {
        isUserInteractionEnabled = true
        
        blurView.isUserInteractionEnabled = true
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        blurView.backgroundColor = UIColor.black.withAlphaComponent(0.5)

    }
    private func setupLayout() {
        addSubview(blurView)
        addSubview(indicatorView)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.centerYAnchor.constraint(equalTo: centerYAnchor),
            blurView.centerXAnchor.constraint(equalTo: centerXAnchor),
            blurView.widthAnchor.constraint(equalToConstant: 67),
            blurView.heightAnchor.constraint(equalToConstant: 67),
            
            indicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorView.widthAnchor.constraint(equalToConstant: 35),
            indicatorView.heightAnchor.constraint(equalToConstant: 35),
            
        ])
    }
    public func startAnimation() {
        indicatorView.startAnimating()
    }
    public func stopAnimation() {
        indicatorView.stopAnimating()
    }
}


extension Reactive where Base: UIView {
    var indicatorAnimator: Binder<Bool> {
        return Binder(self.base) { (targetView, isLoading) in
            if isLoading {
                let indicatorView: IndicatorView
                if let indicator = targetView.subviews.first(where: { $0 is IndicatorView }) as? IndicatorView {
                    indicatorView = indicator
                } else {
                    let indicator = IndicatorView()
                    targetView.addSubview(indicator)
                    indicator.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        indicator.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
                        indicator.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
                        indicator.bottomAnchor.constraint(equalTo: targetView.bottomAnchor),
                        indicator.topAnchor.constraint(equalTo: targetView.topAnchor)
                    ])
                    indicatorView = indicator
                }
                indicatorView.startAnimation()
            } else {
                let indicator = self.base.subviews.first(where: { $0 is IndicatorView }) as? IndicatorView
                indicator?.stopAnimation()
                indicator?.removeFromSuperview()
            }
         }
     }
}
