//
//  UIView++State.swift
//  Pokmon
//
//  Created by drake on 2026/8/31.
//

import UIKit

@MainActor
extension UIView {

    /// 取代 `view.rx.indicatorAnimator`
    func setLoading(_ isLoading: Bool) {
        if isLoading {
            let indicator: IndicatorView
            if let existed = subviews.first(where: { $0 is IndicatorView }) as? IndicatorView {
                indicator = existed
            } else {
                let added = IndicatorView()
                addSubview(added)
                added.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    added.leadingAnchor.constraint(equalTo: leadingAnchor),
                    added.trailingAnchor.constraint(equalTo: trailingAnchor),
                    added.bottomAnchor.constraint(equalTo: bottomAnchor),
                    added.topAnchor.constraint(equalTo: topAnchor)
                ])
                indicator = added
            }
            indicator.startAnimation()
        } else {
            let indicator = subviews.first(where: { $0 is IndicatorView }) as? IndicatorView
            indicator?.stopAnimation()
            indicator?.removeFromSuperview()
        }
    }

    /// 取代 `view.rx.isEmpty`
    func setEmpty(_ isEmpty: Bool) {
        let existed = subviews.first(where: { $0 is EmptyView })
        if isEmpty {
            guard existed == nil else { return }
            let added = EmptyView()
            addSubview(added)
            added.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                added.trailingAnchor.constraint(equalTo: trailingAnchor),
                added.leadingAnchor.constraint(equalTo: leadingAnchor),
                added.topAnchor.constraint(equalTo: topAnchor),
                added.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            existed?.removeFromSuperview()
        }
    }
}
