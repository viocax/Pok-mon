//
//  PokemonAPIClient.swift
//  Pokmon
//
//  Created by drake on 2026/9/1.
//

import Foundation

/// 暴露領域操作，不暴露傳輸層。
///
/// 刻意不做成「丟一個 `Endpoint` 進來」的泛型入口：stored property 不能持有
/// 泛型 closure，硬要做就得型別抹除加執行期轉型，把 `T.Model` 的編譯期關聯
/// 換成 `as?`。改成列舉領域操作之後泛型問題消失，`Endpoint` 的組裝也退回
/// `live` 內部——那才是它該待的位置。
struct PokemonAPIClient: Sendable {
    var list: @Sendable (_ offset: Int) async throws -> PokemonListResponse
    var pokemon: @Sendable (_ id: Int) async throws -> PokmonResponse
    var species: @Sendable (_ id: Int) async throws -> PokemonSpeciesResponse
}

extension PokemonAPIClient {

    /// id 的字串化是 URL path 的細節，收在這裡，呼叫端只認得 `Int`。
    static let live: PokemonAPIClient = {
        let service = APIService.share
        return .init(
            list: { try await service.request(PokemonListEndpont(offset: $0)) },
            pokemon: { try await service.request(PokemonEndpoint(id: "\($0)")) },
            species: { try await service.request(PokemonSpeciesEndpoint(id: "\($0)")) }
        )
    }()
}
