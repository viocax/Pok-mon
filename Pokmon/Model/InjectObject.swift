//
//  InjectObject.swift
//  Pokmon
//
//  Created by drake on 2024/3/11.
//

import Swinject

/// - Description:
/// Thread Safety, container must take `synchronize()` to access all injection
final class InjectObject {
    static let shared: InjectObject = .init()
    #if DEBUG
    private(set) var container: Container = .init()
    #else
    fileprivate let container: Container = .init()
    #endif
    private init() { }
    /// Component Registerations:
    /// must called when an app starts up
    func configuration() {
        self.container.register(FavoriteUseCase.self) { _ in
            return UserDefaultWrapper.share
        }.inObjectScope(.container)
        self.container.register(NetworkService.self) { _ in
            return APIService.share
        }.inObjectScope(.container)
        self.container.register(ListUsecase.self) { _ in
            return ListUseCaseImp()
        }.inObjectScope(.container)
    }
    struct Usecase {
        fileprivate var container: Container
    }
    struct Service {
        fileprivate var container: Container
    }
    var usecase: Usecase {
        return .init(container: container)
    }
    var service: Service {
        return .init(container: container)
    }
}
extension InjectObject.Usecase {
    var favorite: FavoriteUseCase {
        return container.synchronize().resolveService()
    }
    var list: ListUsecase {
        return container.synchronize().resolveService()
    }
}

extension InjectObject.Service {
    var network: NetworkService {
        return container.synchronize().resolveService()
    }
}

extension Resolver {

    func resolveService<Service>() -> Service {
        let di = resolve(Service.self, name: nil)
        #if DEBUG
        #else
        if di == nil {
            PkError.unknown(NSError(domain: "InjectObject", code: 99, userInfo: ["reasone": "\(Service.self) is fail"]))
        }
        #endif
        return di!
    }
}

@propertyWrapper
struct Injected<T> {
    let keyPath: KeyPath<InjectObject, T>
    init(_ keyPath: KeyPath<InjectObject, T>) {
        self.keyPath = keyPath
    }
    var wrappedValue: T {
        return InjectObject.shared[keyPath: keyPath]
    }
}
