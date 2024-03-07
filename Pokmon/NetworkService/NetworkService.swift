//
//  NetworkService.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import RxSwift

protocol NetworkService {
    func request<T: Endpoint>(_ endpoint: T) -> Observable<T.Model>
}

final class APIService: NetworkService {
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
}
