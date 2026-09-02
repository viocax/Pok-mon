//
//  UserDefaultStore.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import Foundation
import os

final class UserDefaultStore: Sendable {

    static let shared: UserDefaultStore = .init()

    /// UserDefaults 的文件保證 thread-safe，但型別本身沒有 Sendable 標註
    nonisolated(unsafe) private let userDefault: UserDefaults
    private let key: String
    private let collection: OSAllocatedUnfairLock<Set<String>>

    init(userDefault: UserDefaults = .standard, key: String = "com.drake.faviorite") {
        self.userDefault = userDefault
        self.key = key
        self.collection = .init(initialState: Set(userDefault.stringArray(forKey: key) ?? []))
    }

    func insert(_ element: String) {
        collection.withLock { _ = $0.insert(element) }
    }

    func remove(_ element: String) {
        collection.withLock { _ = $0.remove(element) }
    }

    func isContain(_ element: String) -> Bool {
        collection.withLock { $0.contains(element) }
    }

    func synchronize() {
        let snapshot = collection.withLock { Array($0) }
        userDefault.setValue(snapshot, forKey: key)
    }
}
