//
//  ErrorTracker.swift
//  Pokmon
//
//  Created by Jie liang Huang on 2024/3/9.
//

import Foundation
import RxCocoa
import RxSwift

class ErrorTracker: SharedSequenceConvertibleType {
    typealias SharingStrategy = DriverSharingStrategy
    private let _subject = PublishSubject<PkError>()

    func trackError<O: ObservableConvertibleType>(from source: O) -> Observable<O.Element> {
        return source.asObservable()
            .do(onError: onErrorDo)
    }

    func asSharedSequence() -> SharedSequence<SharingStrategy, PkError> {
        return _subject.asObservable()
            .asDriver(onErrorDriveWith: .empty())
    }

    func asObservable() -> Observable<PkError> {
        return _subject.asObservable()
    }

    func onErrorDo(_ error: Error) {
        if let info = error as? PkError {
            _subject.onNext(info)
        } else {
            _subject.onNext(PkError.unknown(error))
        }
    }

    deinit {
        _subject.onCompleted()
    }
}

extension ObservableConvertibleType {
    func trackError(_ errorTracker: ErrorTracker) -> Observable<Element> {
        return errorTracker.trackError(from: self)
    }
}
