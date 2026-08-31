//
//  NetworkService.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import RxSwift

protocol NetworkService: Sendable {
    func request<T: Endpoint>(_ endpoint: T) -> Observable<T.Model>
    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model
}

/// Alamofire 的 `Session` 文件保證 thread-safe，但 5.8.1 沒有 Sendable 標註。
/// Task 7 移除 Rx 版 `request` 之後，這個型別會改成 `actor`，屆時可拿掉
/// `@unchecked`——現在還不行，因為 Rx 版是同步回傳，放進 actor 會強迫呼叫端 await。
final class APIService: NetworkService, @unchecked Sendable {
    static let share: APIService = .init()
    private init() {}
    private let session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        let session = Session(configuration: configuration, startRequestsImmediately: false)
        
        return session
    }()
    func request<T: Endpoint>(_ endpoint: T) -> Observable<T.Model> {
        return .create { subscriber in
            do {
                let parameters = try endpoint.setupParameter()
                var urlString = endpoint.baseURL
                if !endpoint.path.isEmpty {
                    urlString += "/\(endpoint.path)"
                }
                guard let url = URL(string: urlString) else {
                    throw PkError.urlError(.init(.badURL))
                }

                var request = URLRequest(url: url)
                request.httpMethod = endpoint.httpMethod.rawValue
                request.headers = endpoint.httpHeaders
                request.timeoutInterval = 30
                
                let newRequest = try endpoint.endcoder.encode(request, with: parameters)
                let dataRequest = self.session.request(newRequest)
                    .responseDecodable(of: T.Model.self) { response in
                        switch response.result {
                        case .success(let model):
                            subscriber.onNext(model)
                            subscriber.onCompleted()
                        case .failure(let fail):
                            subscriber.onError(fail)
                        }
                    }
                dataRequest.resume()
                return Disposables.create {
                    dataRequest.cancel()
                }
            } catch {
                if let afError = error as? AFError {
                    subscriber.onError(PkError.afError(afError))
                } else {
                    subscriber.onError(error)
                }
                return Disposables.create()
            }
        }
    }

    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let dataRequest = try makeRequest(endpoint)
                dataRequest.responseDecodable(of: T.Model.self) { response in
                    switch response.result {
                    case .success(let model):
                        continuation.resume(returning: model)
                    case .failure(let fail):
                        continuation.resume(throwing: PkError.afError(fail))
                    }
                }
                dataRequest.resume()
            } catch let afError as AFError {
                continuation.resume(throwing: PkError.afError(afError))
            } catch {
                continuation.resume(throwing: PkError.unknown(error))
            }
        }
    }

    /// 兩個 request 共用的組裝邏輯
    private func makeRequest<T: Endpoint>(_ endpoint: T) throws -> DataRequest {
        let parameters = try endpoint.setupParameter()
        var urlString = endpoint.baseURL
        if !endpoint.path.isEmpty {
            urlString += "/\(endpoint.path)"
        }
        guard let url = URL(string: urlString) else {
            throw PkError.urlError(.init(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.httpMethod.rawValue
        request.headers = endpoint.httpHeaders
        request.timeoutInterval = 30

        return session.request(try endpoint.endcoder.encode(request, with: parameters))
    }
}
