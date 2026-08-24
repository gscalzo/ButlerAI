import XCTest
@testable import Butler

final class OllamaClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient(model: String = "llama3", serverURL: String = "http://localhost:11434") -> OllamaClient {
        OllamaClient(prompt: "Improve this.", model: model, serverURL: serverURL, session: MockURLProtocol.makeSession())
    }

    // MARK: - Endpoints

    func testChatEndpoint() {
        let endpoint = OllamaClient.chatEndpoint(baseURL: URL(string: "http://localhost:11434")!)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:11434/api/chat")
    }

    func testModelsEndpoint() {
        let endpoint = OllamaClient.modelsEndpoint(baseURL: URL(string: "http://localhost:11434/")!)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:11434/api/tags")
    }

    func testResolveBaseURLFallsBackToLocalhost() {
        XCTAssertEqual(OllamaClient.resolveBaseURL("").absoluteString, OllamaClient.defaultServerURL)
        XCTAssertEqual(OllamaClient.resolveBaseURL("not a url").absoluteString, OllamaClient.defaultServerURL)
        XCTAssertEqual(OllamaClient.resolveBaseURL(" http://ollama.local:11434 ").absoluteString, "http://ollama.local:11434")
    }

    func testResolveBaseURLAddsMissingScheme() {
        XCTAssertEqual(OllamaClient.resolveBaseURL("myhost:11434").absoluteString, "http://myhost:11434")
        XCTAssertEqual(OllamaClient.resolveBaseURL("garbage").absoluteString, "http://garbage")
    }

    func testOllamaErrorEnvelopeBecomesServiceError() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, status: 404, body: #"{"error":"model 'nope' not found"}"#)
        }

        do {
            _ = try await makeClient(model: "nope").improveText("x")
            XCTFail("Expected an error")
        } catch AIServiceError.serviceError(let message) {
            XCTAssertEqual(message, "model 'nope' not found")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBlankModelThrowsMissingModelWithoutRequest() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: "{}")
        }

        do {
            _ = try await makeClient(model: "").improveText("x")
            XCTFail("Expected an error")
        } catch AIServiceError.missingModel {
            XCTAssertEqual(MockURLProtocol.requestCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Chat

    func testImproveTextRoundTrip() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"model":"llama3","message":{"role":"assistant","content":" Better text \n"},"done":true}"#)
        }

        let result = try await makeClient().improveText("improve me")

        XCTAssertEqual(result, "Better text")
        let request = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:11434/api/chat")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

        let json = try MockURLProtocol.lastRequestJSON()
        XCTAssertEqual(json["model"] as? String, "llama3")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual((json["options"] as? [String: Any])?["temperature"] as? Double, OllamaClient.temperature)
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages, [
            ["role": "system", "content": "Improve this."],
            ["role": "user", "content": "improve me"]
        ])
    }

    func testEmptyContentThrowsNoContentInResponse() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"message":{"role":"assistant","content":"   "}}"#)
        }

        do {
            _ = try await makeClient().improveText("x")
            XCTFail("Expected an error")
        } catch AIServiceError.noContentInResponse {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServerErrorBecomesInvalidResponse() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, status: 500, body: "boom")
        }

        do {
            _ = try await makeClient().improveText("x")
            XCTFail("Expected an error")
        } catch AIServiceError.invalidResponse(let statusCode, let body) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(body, "boom")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Models

    func testFetchModelsParsesNames() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"models":[{"name":"llama3","size":1},{"name":"mistral:7b"}]}"#)
        }

        let models = try await OllamaClient.fetchModels(serverURL: "http://localhost:11434", session: MockURLProtocol.makeSession())

        XCTAssertEqual(models, ["llama3", "mistral:7b"])
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "http://localhost:11434/api/tags")
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "GET")
    }

    func testFetchModelsSurfacesHTTPErrors() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, status: 500, body: "down")
        }

        do {
            _ = try await OllamaClient.fetchModels(serverURL: "http://localhost:11434", session: MockURLProtocol.makeSession())
            XCTFail("Expected an error")
        } catch AIServiceError.invalidResponse(let statusCode, _) {
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
