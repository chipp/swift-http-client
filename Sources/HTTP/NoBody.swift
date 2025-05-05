//
//  NoBody.swift
//  swift-http-client
//
//  Created by Vladimir Burdukov on 05/05/2025.
//

import Foundation

public struct NoBody: EncodableBody, DecodableBody {
    public func encode(to _: inout URLRequest) throws {}

    public static func decode(data _: Data, response _: HTTPURLResponse) throws -> NoBody {
        .init()
    }
}
