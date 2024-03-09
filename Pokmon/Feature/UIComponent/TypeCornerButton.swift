//
//  TypeCornerButton.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import UIKit

protocol TypeCornerProtocol {
    var name: String { get }
    var color: UIColor { get }
}

class TypeCornerButton: UIButton {
    
    override var intrinsicContentSize: CGSize {
        return .init(
            width: super.intrinsicContentSize.width,
            height: 24
        )
    }
    init(_ type: any TypeCornerProtocol) {
        super.init(frame: .zero)
        updateStyle(type)
        self.layer.cornerRadius = intrinsicContentSize.height / 2
        self.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.setContentHuggingPriority(.required, for: .horizontal)
        configuration = .plain()
        configuration?.titlePadding = 10
        configuration?.baseForegroundColor = .black
        self.titleLabel?.font = .systemFont(ofSize: 12)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = intrinsicContentSize.height / 2
    }
    func updateStyle(_ type: any TypeCornerProtocol) {
        self.backgroundColor = type.color
        self.setTitle(type.name, for: .normal)
    }
}
