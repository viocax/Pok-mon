//
//  NetworkService.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import Foundation

/// `Session` 自 Alamofire 5.10 起就是 `@unchecked Sendable`——thread-safety 的
/// 保證由 Alamofire 自己給，不必再借 actor 隔離幫忙。少一層 actor 也就少了每個
/// 請求進出隔離域的那次 hop。
///
/// `startRequestsImmediately` 回到預設的 `true`：`DataTask.value` 只 await 結果，
/// **不會**自己 resume（`resume()` 是獨立的公開方法），維持 `false` 會直接掛住。
final class APIService: Sendable {

    static let share: APIService = .init()

    private let session: Alamofire.Session = .init(configuration: URLSessionConfiguration.default)

    private init() {}

    func request<T: Endpoint>(_ endpoint: T) async throws -> T.Model {
        do {
            return try await makeRequest(endpoint)
                .serializingDecodable(T.Model.self)
                .value
        } catch let afError as AFError {
            throw PkError.afError(afError)
        } catch {
            throw PkError.unknown(error)
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
