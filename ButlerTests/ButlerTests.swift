//
//  ButlerTests.swift
//  ButlerTests
//
//  Created by Scalzo, Giordano on 04/03/2025.
//

import XCTest
@testable import Butler
#if canImport(AppIntents)
import AppIntents
#endif

final class ButlerTests: XCTestCase {
    func testDetectLanguageItalian() {
        let service = LanguageService(textImprover: OpenAIClient(
            apiKey: "test-key",
            prompt: "test-prompt",
            model: AIModelConstants.defaultOpenAIModel,
            serverURL: ""
        ))
        let detected = service.detectLanguage(text: "Questo è un test.")
        XCTAssertEqual(detected, "it")
    }

    func testVersionDescriptionFormatting() {
        XCTAssertEqual(AppInfo.versionDescription(version: "1.1.0", build: "2"), "Version 1.1.0 (2)")
        XCTAssertTrue(AppInfo.versionDescription.hasPrefix("Version "))
    }

    func testDetectLanguageNonItalianReturnsNil() {
        let service = LanguageService(textImprover: OpenAIClient(
            apiKey: "test-key",
            prompt: "test-prompt",
            model: AIModelConstants.defaultOpenAIModel,
            serverURL: ""
        ))
        let detected = service.detectLanguage(text: "This is a test.")
        XCTAssertNil(detected)
    }
}
