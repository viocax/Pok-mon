//
//  UIView+Extension.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import UIKit

extension UIView {
    func rotate() {

        let rotation : CABasicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1
        rotation.isCumulative = true
        rotation.repeatCount = Float.greatestFiniteMagnitude
        self.layer.add(rotation, forKey: "rotationAnimation")
    }
    func stopRotate() {
        self.layer.removeAnimation(forKey: "rotationAnimation")
    }
}

extension UIImage {
    static let placeHolder: UIImage? = UIImage(named: "pokeball")
    static let errorImage: UIImage? = .init(named: "errorImage")
}
