//
//  UIStackView++Extension.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import UIKit
import RxSwift

extension UIStackView {
    var types: Binder<[TypeCornerProtocol]> {
        return Binder(self) { stackView, types in
            // TODO: 優化
            stackView.arrangedSubviews.forEach {
                $0.removeFromSuperview()
            }
            types.map(TypeCornerButton.init)
                .forEach { button in
                    stackView.addArrangedSubview(button)
                }
        }
    }
}
