//
//  TaskStore.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//

import Foundation

/// 以 key 管理正在跑的 `Task`。同一個 key 起新工作時會取消舊的 —— Rx `flatMapLatest` 的等價物。
///
/// Task handle 是執行期資源、不是狀態,不能放進 view state;集中在這裡是為了讓
/// store 身上只留下「依賴」與「狀態」。容器被釋放時身上的工作會一起取消,
/// 所以持有它的物件不用再自己寫 `deinit`。
@MainActor
final class TaskStore<Key: Hashable> {

    private var tasks: [Key: Task<Void, Never>] = [:]

    /// 起一個新工作,同 key 的前一個會被取消
    func latest(_ key: Key, operation: @escaping @MainActor () async -> Void) {
        tasks[key]?.cancel()
        tasks[key] = Task { await operation() }
    }

    func cancel(_ key: Key) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    deinit {
        tasks.values.forEach { $0.cancel() }
    }
}
