import XCTest
@testable import Butler

private final class InMemorySecretStore: SecretStoring {
    var values: [String: String] = [:]
    func get(_ key: String) throws -> String? { values[key] }
    func set(_ value: String, for key: String) throws { values[key] = value }
    func delete(_ key: String) throws { values.removeValue(forKey: key) }
}

private struct FailingSecretStore: SecretStoring {
    struct Failure: Error {}
    func get(_ key: String) throws -> String? { nil }
    func set(_ value: String, for key: String) throws { throw Failure() }
    func delete(_ key: String) throws { throw Failure() }
}

final class SettingsServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var secrets: InMemorySecretStore!

    override func setUp() {
        super.setUp()
        suiteName = "ButlerTests.Settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        secrets = InMemorySecretStore()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        secrets = nil
        super.tearDown()
    }

    private func makeService() -> SettingsService {
        SettingsService(defaults: defaults, secrets: secrets)
    }

    func testFreshInstallUsesLunaAndDefaults() {
        let service = makeService()

        XCTAssertEqual(service.aiBackend, .openAI)
        XCTAssertEqual(service.openAIModel, "gpt-5.6-luna")
        XCTAssertEqual(service.openAIModel, AIModelConstants.defaultOpenAIModel)
        XCTAssertEqual(service.activeModel, AIModelConstants.defaultOpenAIModel)
        XCTAssertEqual(service.openAIReasoningEffort, .default)
        XCTAssertEqual(service.openAIBaseURL, SettingsService.defaultOpenAIBaseURL)
        XCTAssertEqual(service.ollamaURL, SettingsService.defaultOllamaURL)
        XCTAssertTrue(service.isUsingDefaultPrompt)
        XCTAssertEqual(defaults.integer(forKey: SettingsService.Keys.schemaVersion), SettingsService.currentSchemaVersion)
    }

    func testLegacyDefaultOpenAIModelIsUpgradedToLuna() {
        defaults.set("gpt-4o-mini", forKey: SettingsService.Keys.legacySelectedModel)
        defaults.set(AIBackendType.openAI.rawValue, forKey: SettingsService.Keys.aiBackend)

        let service = makeService()

        XCTAssertEqual(service.openAIModel, AIModelConstants.defaultOpenAIModel)
        XCTAssertNil(defaults.object(forKey: SettingsService.Keys.legacySelectedModel))
    }

    func testLegacyCustomOpenAIModelIsPreserved() {
        defaults.set("gpt-4.1", forKey: SettingsService.Keys.legacySelectedModel)

        let service = makeService()

        XCTAssertEqual(service.openAIModel, "gpt-4.1")
    }

    func testLegacyOllamaModelMovesToOllamaSlot() {
        defaults.set(AIBackendType.ollama.rawValue, forKey: SettingsService.Keys.aiBackend)
        defaults.set("llama3", forKey: SettingsService.Keys.legacySelectedModel)

        let service = makeService()

        XCTAssertEqual(service.aiBackend, .ollama)
        XCTAssertEqual(service.ollamaModel, "llama3")
        XCTAssertEqual(service.activeModel, "llama3")
        XCTAssertEqual(service.openAIModel, AIModelConstants.defaultOpenAIModel)
    }

    func testMigrationRunsOnlyOnce() {
        _ = makeService()
        defaults.set("gpt-4o-mini", forKey: SettingsService.Keys.openAIModel)

        let service = makeService()

        XCTAssertEqual(service.openAIModel, "gpt-4o-mini", "An explicit post-migration choice must be kept")
    }

    func testActiveModelFollowsBackend() {
        let service = makeService()
        service.ollamaModel = "mistral"

        service.aiBackend = .ollama
        XCTAssertEqual(service.activeModel, "mistral")

        service.aiBackend = .openAI
        XCTAssertEqual(service.activeModel, AIModelConstants.defaultOpenAIModel)
    }

    func testResetImprovementPrompt() {
        let service = makeService()
        service.improvementPrompt = "Custom prompt"
        XCTAssertFalse(service.isUsingDefaultPrompt)

        service.resetImprovementPrompt()

        XCTAssertTrue(service.isUsingDefaultPrompt)
    }

    func testAPIKeyIsPersistedToSecretStore() {
        let service = makeService()

        service.openaiKey = "sk-test"
        XCTAssertEqual(secrets.values[SettingsService.Keys.openAIKey], "sk-test")

        service.openaiKey = ""
        XCTAssertNil(secrets.values[SettingsService.Keys.openAIKey])
    }

    func testAPIKeyIsLoadedFromSecretStore() {
        secrets.values[SettingsService.Keys.openAIKey] = "sk-stored"

        let service = makeService()

        XCTAssertEqual(service.openaiKey, "sk-stored")
    }

    func testLegacyAPIKeyStaysInDefaultsWhenSecretStoreFails() {
        defaults.set("sk-legacy", forKey: SettingsService.Keys.openAIKey)

        let service = SettingsService(defaults: defaults, secrets: FailingSecretStore())

        XCTAssertEqual(service.openaiKey, "sk-legacy")
        XCTAssertEqual(defaults.string(forKey: SettingsService.Keys.openAIKey), "sk-legacy", "The only copy must survive a failed Keychain write")
    }

    func testLegacyAPIKeyInDefaultsIsMovedToSecretStore() {
        defaults.set("sk-legacy", forKey: SettingsService.Keys.openAIKey)

        let service = makeService()

        XCTAssertEqual(service.openaiKey, "sk-legacy")
        XCTAssertEqual(secrets.values[SettingsService.Keys.openAIKey], "sk-legacy")
        XCTAssertNil(defaults.string(forKey: SettingsService.Keys.openAIKey))
    }
}
