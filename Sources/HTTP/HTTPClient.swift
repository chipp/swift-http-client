import Foundation

public enum HTTPAPIError: LocalizedError {
    case errorStatusCode(Int, String?, HTTPURLResponse)
    case missingAuthorizationHandler
    case missingCredentials

    public var errorDescription: String? {
        switch self {
        case let .errorStatusCode(statusCode, _, _):
            "HTTP Status Code: \(statusCode)"
        case .missingAuthorizationHandler:
            "Missing authorization handler"
        case .missingCredentials:
            "Missing credentials"
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
        case .missingAuthorizationHandler:
            return "It's a developer error. Please contact the developer."
        case .missingCredentials:
            return "Missing or invalid credentials."
        }
    }
}

public protocol HTTPAuthorizationHandler {
    func applyAuthorization(
        isolation: isolated (any Actor)?,
        to request: inout URLRequest,
    ) async throws

    func refreshAuthorization(
        isolation: isolated (any Actor)?,
        _ response: HTTPURLResponse,
    ) async throws
}

public protocol HTTPRequestInterceptor: Sendable {
    func interceptRequest(_ request: some Request, urlRequest: inout URLRequest) async throws
}

public actor HTTPClient {
    public let baseURL: URL

    private let session: URLSession

    var authorizationHandler: HTTPAuthorizationHandler?
    var interceptors: [HTTPRequestInterceptor] = []
    var defaultHeaders: [String: String] = [:]

    public init(baseURL: URL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration)
    }

    public func setAuthorizationHandler(_ authorizationHandler: sending HTTPAuthorizationHandler?) {
        self.authorizationHandler = authorizationHandler
    }

    public func setInterceptors(_ interceptors: consuming sending[HTTPRequestInterceptor]) {
        self.interceptors = interceptors
    }

    public func setValue(_ value: String?, forHTTPHeaderField field: String) {
        defaultHeaders[field] = value
    }

    public func sendRequest<R: Request>(_ request: R) async throws -> R.Response {
        let urlRequest = try await createURLRequest(request)
        let (data, response) = try await requestData(urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError()
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                _ = try await refreshAuthorization(httpResponse)
                return try await sendRequest(request)
            }

            throw HTTPAPIError.errorStatusCode(
                httpResponse.statusCode,
                String(bytes: data, encoding: .utf8),
                httpResponse,
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

        for (header, value) in defaultHeaders {
            urlRequest.addValue(value, forHTTPHeaderField: header)
        }

        for (header, value) in request.headers {
            urlRequest.addValue(value, forHTTPHeaderField: header)
        }

        urlRequest.httpMethod = request.method.rawValue
        try request.params.add(to: &urlRequest)
        try request.body.encode(to: &urlRequest)

        for interceptor in interceptors {
            try await interceptor.interceptRequest(request, urlRequest: &urlRequest)
        }

        if request.requiresAuthorization {
            try await applyAuthorization(to: &urlRequest)
        }

        return urlRequest
    }

    private func applyAuthorization(to request: inout URLRequest) async throws {
        guard let authorizationHandler else {
            throw HTTPAPIError.missingAuthorizationHandler
        }

        try await authorizationHandler.applyAuthorization(isolation: #isolation, to: &request)
    }

    private func refreshAuthorization(_ response: HTTPURLResponse) async throws {
        guard let authorizationHandler else {
            throw HTTPAPIError.missingAuthorizationHandler
        }

        try await authorizationHandler.refreshAuthorization(isolation: #isolation, response)
    }
}
