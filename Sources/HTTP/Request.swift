import Foundation

public enum Method: String {
    case GET, POST, PUT, DELETE
}

public protocol Request {
    associatedtype Response: DecodableBody
    associatedtype Body: EncodableBody

    var path: [String] { get }
    var method: Method { get }

    var headers: [String: String] { get }
    var params: Params { get }
    var body: Body { get }

    var requiresAuthorization: Bool { get }
}

public extension Request {
    var headers: [String: String] { [:] }
    var params: Params { .none }
    var body: NoBody { NoBody() }
    var requiresAuthorization: Bool { true }
}
