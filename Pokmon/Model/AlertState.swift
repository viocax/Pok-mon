//
//  AlertState.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation

struct AlertState: Equatable {
    var title: String
    var message: String
}

extension AlertState {
    init(error: Error) {
        self.init(title: "Error ", message: error.localizedDescription)
    }
}
