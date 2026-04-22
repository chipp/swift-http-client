import Foundation
import Testing

@testable import HTTP

struct HTTPClientTests {
    @Test(.timeLimit(.minutes(1)))
    func clientDoesNotRefreshAuthorizationWhenRequestDoesNotRequireIt() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        let client = HTTPClient(baseURL: URL(string: "https://example.com")!, session: session)
        let handler = MockAuthorizationHandler()
        await client.setAuthorizationHandler(handler)

        let request = MockRequest(requiresAuthorization: false)

        do {
            _ = try await client.sendRequest(request)
        } catch {
            // Expected 401 error
        }
        
        #expect(handler.refreshCalled == false, "Refresh authorization should NOT have been called")
    }
    
    @Test(.timeLimit(.minutes(1)))
    func clientAttemptsRefreshAuthorizationWhenRequestRequiresIt() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        let client = HTTPClient(baseURL: URL(string: "https://example.com")!, session: session)
        let handler = MockAuthorizationHandler()
        await client.setAuthorizationHandler(handler)

        let request = MockRequest(requiresAuthorization: true)

        do {
            _ = try await client.sendRequest(request)
        } catch {
            // Expected 401 error
        }
        
        #expect(handler.refreshCalled == true, "Refresh authorization SHOULD have been called")
    }
}

class MockAuthorizationHandler: HTTPAuthorizationHandler, @unchecked Sendable {
    var refreshCalled = false
    
    func applyAuthorization(isolation: isolated (any Actor)?, to request: inout URLRequest) async throws {
        // Not needed for this test
    }
    
    func refreshAuthorization(isolation: isolated (any Actor)?, _ response: HTTPURLResponse) async throws {
        refreshCalled = true
    }
}

struct MockRequest: Request {
    typealias Response = EmptyResponse
    
    var path: [String] = ["test"]
    var method: HTTPMethod = .GET
    var requiresAuthorization: Bool
}

struct EmptyResponse: Decodable, DecodableBody {
    static func decode(data: Data, response: HTTPURLResponse) throws -> EmptyResponse {
        EmptyResponse()
    }
}

class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
