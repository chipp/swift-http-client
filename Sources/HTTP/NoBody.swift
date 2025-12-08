import Foundation

public struct NoBody: EncodableBody, DecodableBody {
    public func encode(to _: inout URLRequest) throws {}

    public static func decode(data _: Data, response _: HTTPURLResponse) throws -> NoBody {
        .init()
    }
}
