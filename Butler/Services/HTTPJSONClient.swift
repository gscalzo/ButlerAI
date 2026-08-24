import Foundation

/// Minimal JSON-over-HTTP transport shared by the AI clients.
///
/// Encodes request bodies, validates the HTTP status, decodes OpenAI-style error envelopes
/// on failure and maps every failure into an `AIServiceError`.
struct HTTPJSONClient {
    /// Reasoning models at higher effort can take well over URLSession's 60s default.
    static let defaultTimeout: TimeInterval = 180

    private let session: URLSession
    private let timeout: TimeInterval
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared, timeout: TimeInterval = HTTPJSONClient.defaultTimeout) {
        self.session = session
        self.timeout = timeout
    }

    func post<Body: Encodable, Response: Decodable>(
        _ url: URL,
        body: Body,
        headers: [String: String] = [:],
        as responseType: Response.Type
    ) async throws -> Response {
        var request = makeRequest(url: url, method: "POST", headers: headers)
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            log("Failed to encode request body: \(error.localizedDescription)", type: .error)
            throw AIServiceError.unknownError(message: "Failed to encode the request: \(error.localizedDescription)")
        }
        log("Request payload prepared (\(request.httpBody?.count ?? 0) bytes)")
        return try await perform(request, as: responseType)
    }

    func get<Response: Decodable>(
        _ url: URL,
        headers: [String: String] = [:],
        as responseType: Response.Type
    ) async throws -> Response {
        let request = makeRequest(url: url, method: "GET", headers: headers)
        return try await perform(request, as: responseType)
    }

    // MARK: - Private

    private func makeRequest(url: URL, method: String, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest, as responseType: Response.Type) async throws -> Response {
        let method = request.httpMethod ?? "?"
        let target = request.url?.absoluteString ?? "?"

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log("Network error during \(method) \(target): \(error.localizedDescription)", type: .error)
            throw AIServiceError.networkError(underlyingError: error)
        }
        log("Received response from \(request.url?.host ?? "server")")

        guard let httpResponse = response as? HTTPURLResponse else {
            log("Error: Invalid response type from server (not HTTPURLResponse)", type: .error)
            throw AIServiceError.invalidResponse(statusCode: 0, responseBody: "Response was not HTTPURLResponse")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            log("HTTP Error: \(httpResponse.statusCode). Body: \(responseBody ?? "nil")", type: .error)
            if let errorResponse = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
                log("AI Service Error: \(errorResponse.error.message)", type: .error)
                throw AIServiceError.serviceError(message: errorResponse.error.message)
            }
            if let errorResponse = try? decoder.decode(OllamaErrorResponse.self, from: data), !errorResponse.error.isEmpty {
                log("AI Service Error: \(errorResponse.error)", type: .error)
                throw AIServiceError.serviceError(message: errorResponse.error)
            }
            throw AIServiceError.invalidResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
        }

        do {
            return try decoder.decode(responseType, from: data)
        } catch let error as DecodingError {
            log("Error decoding response: \(error.localizedDescription)", type: .error)
            throw AIServiceError.responseDecodingError(underlyingError: error)
        } catch {
            log("Unexpected error decoding response: \(error.localizedDescription)", type: .error)
            throw AIServiceError.unknownError(message: error.localizedDescription)
        }
    }
}

/// Normalises user-typed server addresses into absolute http(s) URLs.
enum HTTPURLNormalizer {
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    /// Returns an http(s) URL with a host, adding a scheme when the input has none
    /// (`localhost:1234/v1` → `http://localhost:1234/v1`, `api.example.com/v1` → `https://api.example.com/v1`).
    /// Loopback hosts always get `http`. Returns `nil` for blank or unusable input.
    static func url(from string: String, defaultScheme: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           url.host != nil {
            return url
        }

        // Anything with an explicit non-http scheme (ftp://…) is unusable.
        guard !trimmed.contains("://") else { return nil }

        let authority = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
        let host = authority.split(separator: ":", maxSplits: 1).first.map { String($0).lowercased() } ?? ""
        let scheme = loopbackHosts.contains(host) ? "http" : defaultScheme
        guard let url = URL(string: "\(scheme)://\(trimmed)"), url.host != nil else { return nil }
        return url
    }
}
