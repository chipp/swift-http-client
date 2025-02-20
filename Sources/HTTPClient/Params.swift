import Foundation

public enum Params {
    case none
    case query([String: String])

    func add(to urlRequest: inout URLRequest) throws {
        switch self {
        case .none:
            break
        case let .query(params):
            guard
                let url = urlRequest.url,
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                break
            }

            var queryItems = components.queryItems ?? []

            for (key, value) in params {
                queryItems.append(.init(name: key, value: value))
            }

            components.queryItems = queryItems

            urlRequest.url = components.url
        }
    }
}
