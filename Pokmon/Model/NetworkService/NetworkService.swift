//
//  NetworkService.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import Foundation

/// 用 actor 把 Alamofire 的 `Session` 關起來。
/// `Session` 的文件說它 thread-safe,但 5.8.1 沒有 Sendable 標註;與其在型別上
/// 掛 `@unchecked Sendable` 自己保證,不如讓編譯器用 actor 隔離幫忙保證。
actor APIService {

    static let share: APIService = .init()

    private let session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        return Session(configuration: configuration, startRequestsImmediately: false)
    }()

    private init() {}

    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model {
        try await withCheckedThrowingContinuation { continuation in
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
