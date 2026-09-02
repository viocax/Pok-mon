//
//  Encodable++Extension.swift
//  Pokmon
//
//  Created by drake on 2024/3/7.
//

import Alamofire
import Foundation

extension Encodable {
    func encodeToParameter() throws -> Parameters? {
        guard let data = try? JSONEncoder().encode(self) else {
            throw PkError.badRequest
        }
        // Alamofire 5.10 起 `Parameters` 是 `[String: any Any & Sendable]`，不再是
        // `[String: Any]`。`JSONSerialization` 吐出來的是不可變的橋接型別
        // （`__NSCFNumber`、`__NSArrayI` …），實測連巢狀集合都滿足 `Sendable`，
        // 所以這個動態轉型不會在執行期無聲失敗。
        guard let dic = try? JSONSerialization.jsonObject(with: data) as? Parameters else {
            throw PkError.badRequest
        }
        return dic
    }
}
