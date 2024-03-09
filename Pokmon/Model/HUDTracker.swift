//
//  HUDTracker.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import Foundation
import RxCocoa
import RxSwift

class HUDTracker: SharedSequenceConvertibleType {
    typealias Element = Bool
    typealias SharingStrategy = DriverSharingStrategy
    private let _lock = NSRecursiveLock()
    private let _publishRelay = BehaviorRelay<Bool>(value: false)
    private let _loading: SharedSequence<SharingStrategy, Bool>
    init() {
        _loading = _publishRelay.asDriver()
            .distinctUntilChanged()
    }
    fileprivate func trackActivityOfObservable<O: ObservableConvertibleType>(_ source: O) -> Observable<O.Element> {
        return source.asObservable()
            .do(onNext: { _ in
                self.sendStopLoading()
            }, onError: { _ in
                self.sendStopLoading()
            }, onCompleted: {
                self.sendStopLoading()
            }, onSubscribe: {
                self.subscribed()
            })
    }
    private func subscribed() {
        _lock.lock(); defer { _lock.unlock() }
        _publishRelay.accept(true)
    }
    private func sendStopLoading() {
        _lock.lock(); defer { _lock.unlock() }
        _publishRelay.accept(false)
    }
    func asSharedSequence() -> SharedSequence<SharingStrategy, Element> {
        return _loading
    }
}

extension ObservableConvertibleType {
    func trackActivity(_ activityIndicator: HUDTracker) -> Observable<Element> {
        return activityIndicator.trackActivityOfObservable(self)
    }
}
