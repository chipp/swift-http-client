import Foundation

public enum HTTPAPIError: LocalizedError {
    case errorStatusCode(Int, String?, HTTPURLResponse)

    public var errorDescription: String? {
        switch self {
        case let .errorStatusCode(statusCode, _, _):
            "HTTP Status Code: \(statusCode)"
        }
    }

    public var failureReason: String? {
        switch self {
        case let .errorStatusCode(_, body, response):
            var result = "\(response.url?.absoluteString ?? "N/A")\n"
            if let body {
                result += body
            }
            return result
        }
    }
}

public protocol HTTPAuthenticator: AnyObject, Sendable {
    func applyAuthorization(to request: inout URLRequest) async throws
    func refreshAuthorization(_ response: HTTPURLResponse) async throws
}

public final class HTTPClient: Sendable {
    public let baseURL: URL

    @HTTPClientActor
    private weak var authenticator: HTTPAuthenticator?

    @HTTPClientActor
    private var defaultHeaders: [String: String] = [:]

    private let session: URLSession

    public init(baseURL: URL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration)
    }

    public func setAuthenticator(_ authenticator: HTTPAuthenticator) {
        Task { @HTTPClientActor in
            self.authenticator = authenticator
        }
    }

    public func setValue(_ value: String?, forHTTPHeaderField field: String) {
        Task { @HTTPClientActor in
            defaultHeaders[field] = value
        }
    }

    public func sendRequest<R: Request>(_ request: R) async throws -> R.Response {
        let urlRequest = try await createURLRequest(request)
        let (data, response) = try await requestData(urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError()
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401, let authenticator = await authenticator {
                _ = try await authenticator.refreshAuthorization(httpResponse)
                return try await sendRequest(request)
            }

            throw HTTPAPIError.errorStatusCode(
                httpResponse.statusCode,
                String(bytes: data, encoding: .utf8),
                httpResponse
            )
        }

        return try R.Response.decode(data: data, response: httpResponse)
    }

    private func requestData(_ urlRequest: URLRequest) async throws -> (data: Data, response: URLResponse) {
        try await session.data(for: urlRequest)
    }

    private func createURLRequest(_ request: some Request) async throws -> URLRequest {
        var url = baseURL

        for component in request.path {
            url.appendPathComponent(component)
        }

        var urlRequest = URLRequest(url: url)

        for (header, value) in await defaultHeaders {
            urlRequest.addValue(value, forHTTPHeaderField: header)
        }

        for (header, value) in request.headers {
            urlRequest.addValue(value, forHTTPHeaderField: header)
        }

        if let authenticator = await authenticator, request.requiresAuthorization {
            try await authenticator.applyAuthorization(to: &urlRequest)
        }

        urlRequest.httpMethod = request.method.rawValue
        try request.params.add(to: &urlRequest)
        try request.body.encode(to: &urlRequest)

        return urlRequest
    }
}
