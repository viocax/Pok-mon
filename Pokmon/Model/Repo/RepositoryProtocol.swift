//
//  RepositoryProtocol.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import Foundation

protocol RepositoryProtocol: AnyObject {
    func save<T>(_ key: String, value: T)
    func getValue<T>(_ key: String) -> T?
    func synchronize()
}

final class UserDefaultWrapper: RepositoryProtocol {
    private let userDefault: UserDefaults
    init(userDefault: UserDefaults = .standard) {
        self.userDefault = userDefault
    }
    func save<T>(_ key: String, value: T) {
        userDefault.setValue(value, forKey: key)
    }
    func getValue<T>(_ key: String) -> T? {
        return userDefault.value(forKey: key) as? T
    }
    func synchronize() {
        userDefault.synchronize()
    }
}
