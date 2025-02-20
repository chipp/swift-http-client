import Foundation

public protocol EncodableBody {
    func encode(to urlRequest: inout URLRequest) throws
}

public protocol JSONEncodableBody: EncodableBody, Encodable {
    static var encoder: JSONEncoder { get }
}

public extension JSONEncodableBody {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    func encode(to urlRequest: inout URLRequest) throws {
        urlRequest.httpBody = try Self.encoder.encode(self)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}

public struct NoBody: EncodableBody {
    public func encode(to _: inout URLRequest) throws {}
}

public struct URLEncodedBody: EncodableBody {
    private let params: [String: String]
    public init(params: [String: String]) {
        self.params = params
    }

    private static let charset: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()

    public func encode(to urlRequest: inout URLRequest) throws {
        var queryItems: [(key: String, value: String)] = []

        for (key, value) in params {
            queryItems.append((
                key,
                value.addingPercentEncoding(withAllowedCharacters: Self.charset) ?? value
            ))
        }

        let string = queryItems.map { "\($0)=\($1)" }.joined(separator: "&")
        guard let data = string.data(using: .utf8) else {
            fatalError()
        }

        urlRequest.httpBody = data
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
}

public struct MultipartFormDataBody: EncodableBody {
    public struct File {
        public let data: Data
        public let contentType: String
        public let filename: String

        public init(data: Data, contentType: String, filename: String) {
            self.data = data
            self.contentType = contentType
            self.filename = filename
        }
    }

    private let params: [String: String]
    private let files: [String: File]

    public init(params: [String: String] = [:], files: [String: File] = [:]) {
        self.params = params
        self.files = files
    }

    public func encode(to urlRequest: inout URLRequest) throws {
        let boundary = UUID().uuidString
        var data = Data()

        for (key, value) in params.sorted(using: KeyPathComparator(\.key)) {
            data.append(contentsOf: "--\(boundary)\r\n".utf8)
            data.append(contentsOf: "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8)
            data.append(contentsOf: "\(value)\r\n".utf8)
        }

        for (key, file) in files.sorted(using: KeyPathComparator(\.key)) {
            data.append(contentsOf: "--\(boundary)\r\n".utf8)
            data.append(contentsOf: "Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(file.filename)\"\r\n".utf8)
            data.append(contentsOf: "Content-Type: \(file.contentType)\r\n\r\n".utf8)
            data.append(file.data)
            data.append(contentsOf: [0x0D, 0x0A])
        }

        data.append(contentsOf: "--\(boundary)--\r\n".utf8)

        urlRequest.httpBody = data
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }
}
