//
//  UIViewController++Extension.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import UIKit

extension UIViewController {

    /// `onDismiss` 是給狀態容器把 alert 清掉用的
    func presentAlert(_ alert: AlertState, onDismiss: (() -> Void)? = nil) {
        let controller = UIAlertController(
            title: alert.title,
            message: alert.message,
            preferredStyle: .alert
        )
        controller.addAction(.init(title: "ok", style: .default) { _ in onDismiss?() })
        present(controller, animated: true)
    }
}
