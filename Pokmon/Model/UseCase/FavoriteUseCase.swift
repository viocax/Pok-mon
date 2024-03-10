//
//  FavoriteUseCase.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import Foundation

protocol FavoriteUseCase: AnyObject {
    func insert(_ element: String)
    func isContain(_ element: String) -> Bool
    func remove(_ element: String)
    var isEmpty: Bool { get }
    func synchronize()
}

final class UserDefaultWrapper: FavoriteUseCase {
    private let userDefault: UserDefaults
    private let key: String
    private var collection: Set<String> = .init()
    static let share: UserDefaultWrapper = .init()

    init(userDefault: UserDefaults = .standard, key: String = "com.drake.faviorite") {
        self.userDefault = userDefault
        self.key = key
    }
    var isEmpty: Bool {
        return collection.isEmpty
    }
    func insert(_ element: String) {
        collection.insert(element)
    }
    func remove(_ element: String) {
        collection.remove(element)
    }
    func isContain(_ element: String) -> Bool {
        return collection.contains(element)
    }
    func synchronize() {
        userDefault.setValue(Array(collection), forKey: key)
        userDefault.synchronize()
    }
}
