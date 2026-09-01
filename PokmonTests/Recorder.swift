//
//  Recorder.swift
//  PokmonTests
//
//  Created by drake on 2026/9/1.
//

import os

/// 測試用的執行緒安全記錄器。
///
/// 用 lock 而不是 actor：`FavoritesClient` 的 closure 是同步的，actor 版在同步
/// closure 裡無法 `await`，會逼出兩套寫法。
///
/// 它本質上是把 mock class 的可變欄位換了個位置——價值在於範圍更小（只記錄，
/// 不假裝實作介面）且 `Sendable` 由編譯器保證，而不是消滅了可變狀態。
final class Recorder<Value: Sendable>: Sendable {

    private let storage = OSAllocatedUnfairLock<[Value]>(initialState: [])

    func record(_ value: Value) {
        storage.withLock { $0.append(value) }
    }

    var recorded: [Value] {
        storage.withLock { $0 }
    }

    var count: Int {
        storage.withLock { $0.count }
    }
}
