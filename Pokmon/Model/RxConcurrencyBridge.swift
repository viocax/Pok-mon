//
//  RxConcurrencyBridge.swift
//  Pokmon
//
//  Created by drake on 2026/8/21.
//
//  Rx 與 Swift Concurrency 的邊界轉接。
//  用在「還沒搬過去的 Rx 介面」與「async 呼叫端」交界的那一層,
//  不要散在 store / view model 裡面。
//

import RxSwift

extension ObservableConvertibleType {
    /// 等這條 Observable 的第一個值。
    ///
    /// 完成(沒發過值)、錯誤、或外層 Task 被取消,一律回 `nil`。
    /// 底層用 RxSwift 6.6 內建的 `values`(`AsyncThrowingStream`),
    /// 它的 `onTermination` 已經處理好「Task 取消 → dispose 訂閱」,不需要自己刻 continuation。
    func firstValue() async -> Element? {
        do {
            for try await value in asObservable().take(1).values {
                return value
            }
            return nil
        } catch {
            // onError 與 CancellationError 都走這裡
            return nil
        }
    }
}
