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
        self.titleLabel?.font = .systemFont(ofSize: 12)
        self.layer.cornerRadius = intrinsicContentSize.height / 2
        updateStyle(type)
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
