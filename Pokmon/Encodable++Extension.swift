//
//  Encodable++Extension.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire

extension Encodable {
    func encodeToParameter() throws -> Parameters? {
        guard let data = try? JSONEncoder().encode(self) else {
            throw PkError.badRequest
        }
        guard let dic = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PkError.badRequest
        }
        return dic
    }
}
