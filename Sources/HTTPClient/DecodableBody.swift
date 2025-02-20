import Foundation

public protocol DecodableBody {
    static func decode(data: Data, response: HTTPURLResponse) throws -> Self
}

public protocol JSONDecodableBody: DecodableBody, Decodable {
    static var decoder: JSONDecoder { get }
}

public extension JSONDecodableBody {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func decode(data: Data, response _: HTTPURLResponse) throws -> Self {
        try decoder.decode(Self.self, from: data)
    }
}

extension Array: DecodableBody where Element: JSONDecodableBody {}
extension Array: JSONDecodableBody where Element: JSONDecodableBody {}
