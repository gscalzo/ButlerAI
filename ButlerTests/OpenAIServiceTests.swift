import XCTest
@testable import Butler

final class OpenAIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient(
        apiKey: String = "test-key",
        model: String = AIModelConstants.defaultOpenAIModel,
        serverURL: String = "",
        reasoningEffort: OpenAIReasoningEffort = .default
    ) -> OpenAIClient {
        OpenAIClient(
            apiKey: apiKey,
            prompt: "Improve this.",
            model: model,
            serverURL: serverURL,
            reasoningEffort: reasoningEffort,
            session: MockURLProtocol.makeSession()
        )
    }

    private func jsonKeys(of request: OpenAIChatRequest) throws -> Set<String> {
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }

    private func captureError(_ work: () async throws -> Void) async -> AIServiceError? {
        do {
            try await work()
            XCTFail("Expected an AIServiceError to be thrown")
            return nil
        } catch let error as AIServiceError {
            return error
        } catch {
            XCTFail("Unexpected error type: \(error)")
            return nil
        }
    }

    // MARK: - Endpoints

    func testChatEndpointWithV1BaseURL() {
        let endpoint = OpenAIClient.chatEndpoint(baseURL: URL(string: "https://api.openai.com/v1")!)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testChatEndpointWithV1BaseURLAndTrailingSlash() {
        let endpoint = OpenAIClient.chatEndpoint(baseURL: URL(string: "https://api.openai.com/v1/")!)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testChatEndpointWithBareBaseURL() {
        let endpoint = OpenAIClient.chatEndpoint(baseURL: URL(string: "https://api.openai.com")!)
        XCTAssertEqual(endpoint.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testChatEndpointWithCustomBaseURL() {
        let endpoint = OpenAIClient.chatEndpoint(baseURL: URL(string: "http://localhost:1234")!)
        XCTAssertEqual(endpoint.absoluteString, "http://localhost:1234/v1/chat/completions")
    }

    func testResolveBaseURLFallsBackToOfficialAPI() {
        XCTAssertEqual(OpenAIClient.resolveBaseURL(""), OpenAIClient.defaultBaseURL)
        XCTAssertEqual(OpenAIClient.resolveBaseURL("   \n"), OpenAIClient.defaultBaseURL)
        XCTAssertEqual(OpenAIClient.resolveBaseURL("not a url"), OpenAIClient.defaultBaseURL)
        XCTAssertEqual(OpenAIClient.resolveBaseURL("ftp://example.com/v1"), OpenAIClient.defaultBaseURL)
        XCTAssertEqual(OpenAIClient.resolveBaseURL(" http://localhost:1234/v1 ").absoluteString, "http://localhost:1234/v1")
    }

    func testResolveBaseURLAddsMissingScheme() {
        XCTAssertEqual(OpenAIClient.resolveBaseURL("localhost:1234/v1").absoluteString, "http://localhost:1234/v1")
        XCTAssertEqual(OpenAIClient.resolveBaseURL("127.0.0.1:8080").absoluteString, "http://127.0.0.1:8080")
        XCTAssertEqual(OpenAIClient.resolveBaseURL("api.example.com/v1").absoluteString, "https://api.example.com/v1")
        XCTAssertEqual(OpenAIClient.resolveBaseURL("nonsense").absoluteString, "https://nonsense")
    }

    // MARK: - Reasoning effort support

    func testReasoningEffortNoneIsOnlyOfferedToCatalogModels() {
        XCTAssertEqual(OpenAIClient.supportedReasoningEfforts(model: "gpt-5.6-luna"), OpenAIReasoningEffort.allCases)
        XCTAssertEqual(OpenAIClient.supportedReasoningEfforts(model: "gpt-5-mini"), [.low, .medium, .high])
        XCTAssertEqual(OpenAIClient.supportedReasoningEfforts(model: "o3-mini"), [.low, .medium, .high])
        XCTAssertEqual(OpenAIClient.supportedReasoningEfforts(model: "gpt-4o-mini"), [])
    }

    func testUnsupportedReasoningEffortFallsBackToDefault() {
        XCTAssertEqual(makeClient(model: "gpt-5-mini", reasoningEffort: .none).makeRequestBody(for: "x").reasoningEffort, OpenAIReasoningEffort.default.rawValue)
        XCTAssertEqual(makeClient(model: "gpt-5.6-luna", reasoningEffort: .none).makeRequestBody(for: "x").reasoningEffort, "none")
        XCTAssertEqual(makeClient(model: "gpt-5-mini", reasoningEffort: .high).makeRequestBody(for: "x").reasoningEffort, "high")
    }

    // MARK: - Guards

    func testTruncatedResponseIsRejected() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"choices":[{"message":{"role":"assistant","content":"partial rewrite"},"finish_reason":"length"}]}"#)
        }

        let error = await captureError { _ = try await makeClient().improveText("x") }

        guard case .responseTruncated = error else {
            return XCTFail("Expected responseTruncated, got \(String(describing: error))")
        }
    }

    func testBlankModelThrowsMissingModelWithoutRequest() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: "{}")
        }

        let error = await captureError { _ = try await makeClient(model: "   ").improveText("x") }

        guard case .missingModel = error else {
            return XCTFail("Expected missingModel, got \(String(describing: error))")
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }

    func testRequestsUseExtendedTimeout() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"choices":[{"message":{"role":"assistant","content":"ok"}}]}"#)
        }

        _ = try await makeClient().improveText("x")

        XCTAssertEqual(MockURLProtocol.lastRequest?.timeoutInterval, HTTPJSONClient.defaultTimeout)
    }

    // MARK: - Defaults and catalog

    func testDefaultModelIsLuna() {
        XCTAssertEqual(AIModelConstants.defaultOpenAIModel, "gpt-5.6-luna")
        XCTAssertFalse(AIModelConstants.previousDefaultOpenAIModels.contains(AIModelConstants.defaultOpenAIModel))
    }

    func testCatalogListsLunaFirstAndRecognisesKnownModels() {
        XCTAssertEqual(OpenAIModelCatalog.options.first?.id, AIModelConstants.defaultOpenAIModel)
        XCTAssertEqual(OpenAIModelCatalog.options.map(\.id), ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"])
        XCTAssertTrue(OpenAIModelCatalog.isKnown("gpt-5.6-luna"))
        XCTAssertTrue(OpenAIModelCatalog.isKnown(" gpt-5.6-sol "))
        XCTAssertFalse(OpenAIModelCatalog.isKnown("gpt-4o-mini"))
        XCTAssertEqual(OpenAIModelCatalog.option(for: "gpt-5.6-terra")?.displayName, "GPT-5.6 Terra")
        XCTAssertNil(OpenAIModelCatalog.option(for: "llama3"))
    }

    func testReasoningEffortDefaultsToLow() {
        XCTAssertEqual(OpenAIReasoningEffort.default, .low)
        XCTAssertEqual(OpenAIReasoningEffort.allCases.map(\.rawValue), ["none", "low", "medium", "high"])
    }

    // MARK: - Model capabilities

    func testUsesReasoningParametersForGPT5AndOSeriesModels() {
        for model in ["gpt-5.6-luna", "gpt-5.6-sol", "GPT-5-mini", " gpt-5 ", "o1", "o3-mini", "o4-mini"] {
            XCTAssertTrue(OpenAIClient.usesReasoningParameters(model: model), model)
        }
    }

    func testDoesNotUseReasoningParametersForLegacyModels() {
        for model in ["gpt-4o-mini", "gpt-4.1", "gpt-4o", "llama3", "ollama", ""] {
            XCTAssertFalse(OpenAIClient.usesReasoningParameters(model: model), model)
        }
    }

    // MARK: - Request body

    func testRequestBodyForReasoningModelUsesCompletionTokensAndEffort() throws {
        let client = makeClient(model: "gpt-5.6-luna", reasoningEffort: .medium)
        let body = client.makeRequestBody(for: "hello")

        XCTAssertEqual(body.model, "gpt-5.6-luna")
        XCTAssertEqual(body.messages, [.system("Improve this."), .user("hello")])
        XCTAssertEqual(body.maxCompletionTokens, OpenAIClient.maxReasoningCompletionTokens)
        XCTAssertEqual(body.reasoningEffort, "medium")
        XCTAssertNil(body.maxTokens)
        XCTAssertNil(body.temperature)

        let keys = try jsonKeys(of: body)
        XCTAssertTrue(keys.contains("max_completion_tokens"))
        XCTAssertTrue(keys.contains("reasoning_effort"))
        XCTAssertFalse(keys.contains("temperature"))
        XCTAssertFalse(keys.contains("max_tokens"))
    }

    func testRequestBodyForLegacyModelUsesMaxTokensAndTemperature() throws {
        let client = makeClient(model: "gpt-4o-mini")
        let body = client.makeRequestBody(for: "hello")

        XCTAssertEqual(body.maxTokens, OpenAIClient.maxOutputTokens)
        XCTAssertEqual(body.temperature, OpenAIClient.legacyTemperature)
        XCTAssertNil(body.maxCompletionTokens)
        XCTAssertNil(body.reasoningEffort)

        let keys = try jsonKeys(of: body)
        XCTAssertTrue(keys.contains("max_tokens"))
        XCTAssertTrue(keys.contains("temperature"))
        XCTAssertFalse(keys.contains("reasoning_effort"))
        XCTAssertFalse(keys.contains("max_completion_tokens"))
    }

    func testRequestBodyNeverContainsSamplingPenalties() throws {
        for model in ["gpt-5.6-luna", "gpt-4o-mini"] {
            let keys = try jsonKeys(of: makeClient(model: model).makeRequestBody(for: "hello"))
            XCTAssertEqual(keys.intersection(["top_p", "frequency_penalty", "presence_penalty"]), [], model)
        }
    }

    // MARK: - Round-trips

    func testImproveTextSendsAuthorizedRequestAndReturnsTrimmedContent() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: """
            {
              "id": "chatcmpl-1",
              "object": "chat.completion",
              "created": 1,
              "model": "gpt-5.6-luna",
              "choices": [
                {"index": 0, "message": {"role": "assistant", "content": "  Improved text \\n"}, "finish_reason": "stop"}
              ],
              "usage": {"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3}
            }
            """)
        }

        let result = try await makeClient().improveText("improve me")

        XCTAssertEqual(result, "Improved text")
        let request = try XCTUnwrap(MockURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = try MockURLProtocol.lastRequestJSON()
        XCTAssertEqual(json["model"] as? String, "gpt-5.6-luna")
        XCTAssertEqual(json["reasoning_effort"] as? String, "low")
        XCTAssertEqual(json["max_completion_tokens"] as? Int, OpenAIClient.maxReasoningCompletionTokens)
        XCTAssertNil(json["temperature"])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages, [
            ["role": "system", "content": "Improve this."],
            ["role": "user", "content": "improve me"]
        ])
    }

    func testImproveTextUsesCustomBaseURL() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"choices":[{"message":{"role":"assistant","content":"ok"}}]}"#)
        }

        _ = try await makeClient(serverURL: "http://localhost:1234/v1").improveText("x")

        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "http://localhost:1234/v1/chat/completions")
    }

    func testMinimalResponseWithoutMetadataDecodes() async throws {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"choices":[{"message":{"role":"assistant","content":"ok"}}]}"#)
        }

        let result = try await makeClient().improveText("x")
        XCTAssertEqual(result, "ok")
    }

    func testServiceErrorMessageIsSurfaced() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, status: 401, body: #"{"error":{"message":"bad key","type":"invalid_request_error"}}"#)
        }

        let error = await captureError { _ = try await self.makeClient().improveText("x") }
        guard case .serviceError(let message)? = error else {
            return XCTFail("Expected serviceError, got \(String(describing: error))")
        }
        XCTAssertEqual(message, "bad key")
    }

    func testNonJSONErrorBodyBecomesInvalidResponse() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, status: 500, body: "<html>Bad Gateway</html>")
        }

        let error = await captureError { _ = try await self.makeClient().improveText("x") }
        guard case .invalidResponse(let statusCode, let body)? = error else {
            return XCTFail("Expected invalidResponse, got \(String(describing: error))")
        }
        XCTAssertEqual(statusCode, 500)
        XCTAssertEqual(body, "<html>Bad Gateway</html>")
    }

    func testNullContentThrowsNoContentInResponse() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.respond(to: request, body: #"{"choices":[{"index":0,"message":{"role":"assistant","content":null,"refusal":"I can't help with that."},"finish_reason":"stop"}]}"#)
        }

        let error = await captureError { _ = try await self.makeClient().improveText("x") }
        guard case .noContentInResponse? = error else {
            return XCTFail("Expected noContentInResponse, got \(String(describing: error))")
        }
    }

    func testBlankApiKeyThrowsWithoutMakingARequest() async {
        MockURLProtocol.requestHandler = { request in
            XCTFail("No request should be made when the API key is blank")
            return MockURLProtocol.respond(to: request, body: "{}")
        }

        let error = await captureError { _ = try await self.makeClient(apiKey: "  ").improveText("x") }
        guard case .missingApiKey? = error else {
            return XCTFail("Expected missingApiKey, got \(String(describing: error))")
        }
        XCTAssertEqual(MockURLProtocol.requestCount, 0)
    }

    func testTransportFailureBecomesNetworkError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        let error = await captureError { _ = try await self.makeClient().improveText("x") }
        guard case .networkError? = error else {
            return XCTFail("Expected networkError, got \(String(describing: error))")
        }
    }
}
