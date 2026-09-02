//
//  UIStackView++Extension.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import UIKit

extension UIStackView {
    func setTypes(_ types: [any TypeCornerProtocol]) {
        // TODO: 優化
        arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        types.map(TypeCornerButton.init)
            .forEach { button in
                addArrangedSubview(button)
            }
    }
}
