import Foundation
import XCTest

/// Intercepts every request made through a session built with `makeSession()`, records it
/// (including the body, which URLSession moves into `httpBodyStream`) and answers with the
/// response produced by `requestHandler`.
final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private static var storedHandler: Handler?
    private static var storedLastRequest: URLRequest?
    private static var storedLastRequestBody: Data?
    private static var storedRequestCount = 0

    static var requestHandler: Handler? {
        get { lock.withLock { storedHandler } }
        set { lock.withLock { storedHandler = newValue } }
    }

    static var lastRequest: URLRequest? {
        lock.withLock { storedLastRequest }
    }

    static var lastRequestBody: Data? {
        lock.withLock { storedLastRequestBody }
    }

    static var requestCount: Int {
        lock.withLock { storedRequestCount }
    }

    static func reset() {
        lock.withLock {
            storedHandler = nil
            storedLastRequest = nil
            storedLastRequestBody = nil
            storedRequestCount = 0
        }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// The last request body decoded as a JSON object.
    static func lastRequestJSON(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let body = try XCTUnwrap(lastRequestBody, "No request body captured", file: file, line: line)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any],
            "Request body is not a JSON object",
            file: file,
            line: line
        )
    }

    /// Convenience for handlers: an HTTP response with the given status and body for the incoming request.
    static func respond(to request: URLRequest, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.invalid")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(of: request)
        Self.lock.withLock {
            Self.storedLastRequest = request
            Self.storedLastRequestBody = body
            Self.storedRequestCount += 1
        }

        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
