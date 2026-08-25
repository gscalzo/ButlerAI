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

    /// Accessory apps must become active before showing a window, otherwise AppKit orders it
    /// beneath the frontmost app and Settings/Logs look as if they never opened. Activation is
    /// only a request, so the windows are also raised afterwards.
    @MainActor
    func testMenuWindowOpenerActivatesTheAppThenShowsAndRaisesTheWindow() {
        var events: [String] = []
        let raised = expectation(description: "windows raised")
        let opener = MenuWindowOpener(
            activateApp: { events.append("activate") },
            bringWindowsToFront: { events.append("raise"); raised.fulfill() }
        )

        opener.open { events.append("show") }

        XCTAssertEqual(events, ["activate", "show"])
        wait(for: [raised], timeout: 1)
        XCTAssertEqual(events, ["activate", "show", "raise"])
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
