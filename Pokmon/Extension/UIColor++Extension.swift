//
//  UIColor++Extension.swift
//  Pokmon
//
//  Created by drake on 2024/3/8.
//

import UIKit

extension UIColor {
    static func hex(_ hex: Int, alpha: CGFloat = 1.0) -> UIColor {
        let components = (
            R: Double((hex >> 16) & 0xff) / 255,
            G: Double((hex >> 08) & 0xff) / 255,
            B: Double((hex >> 00) & 0xff) / 255
        )

        return self.init(
            red: components.R,
            green: components.G,
            blue: components.B,
            alpha: alpha
        )
    }
}
