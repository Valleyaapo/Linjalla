//
//  RT_BusUITests.swift
//  RT BusUITests
//
//  Created by Automation on 30.12.2025.
//

import XCTest
import CoreGraphics

final class RT_BusUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainMap() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITesting")
        app.launch()
        
        handleLocationDialog(app)

        XCTAssertTrue(app.otherElements["MainMapView"].waitForExistence(timeout: 10))
        
        // Ensure map is centered
        if app.buttons["CenterStationButton"].exists {
            app.buttons["CenterStationButton"].tap()
        }
        
        // Allow time for simulated buses to appear
        sleep(2)
        
        takeScreenshot(named: "Main_Map")
    }

    func testSearchAndAddLine() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITesting")
        app.launch()
        
        handleLocationDialog(app)
        
        // Ensure map is centered
        if app.buttons["CenterStationButton"].exists {
            app.buttons["CenterStationButton"].tap()
        }
        
        let existingToggle = findLineToggle(app, identifier: "LineToggle_HSL_2550")
        let wasFavorite = existingToggle.exists

        // Open Add Line Sheet
        let addButton = app.buttons["AddLineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Add Line button missing")
        addButton.tap()
        
        // Search
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("550")
        
        // Expect result
        let row = app.otherElements["LineSearchRow_HSL_2550"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let toggleButton = row.buttons["LineSearchToggle_HSL_2550"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5))
        if !wasFavorite {
            toggleButton.tap()
        }
        takeScreenshot(named: "Search_Results")

        dismissLineSearchSheetIfNeeded(app)

        // Ensure selection shows the added line
        let lineToggle = findLineToggle(app, identifier: "LineToggle_HSL_2550")
        XCTAssertTrue(lineToggle.waitForExistence(timeout: 10))
        ensureLineSelected(lineToggle)
    }
    func testEmptySearch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITesting")
        app.launch()
        
        handleLocationDialog(app)
        
        // Open Add Line Sheet
        let addButton = app.buttons["AddLineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()
        
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("9999")

        let emptyState = app.otherElements["LineSearchNoResults"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 10))
        
        takeScreenshot(named: "Search_Empty")
    }
    
    func testDeparturesSheet() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITesting")
        app.launch()
        
        handleLocationDialog(app)
        
        // Ensure map is centered
        if app.buttons["CenterStationButton"].exists {
            app.buttons["CenterStationButton"].tap()
        }

        addLine550IfNeeded(app)
        
        let departuresButton = app.buttons["DeparturesButton"]
        if departuresButton.waitForExistence(timeout: 5) {
            openDeparturesSheet(app, button: departuresButton)
            assertElementExists(app, identifier: "DeparturesList", timeout: 10)
            assertElementExists(app, identifier: "DepartureRow_550", timeout: 15)
            takeScreenshot(named: "Departures_Open")
        }
    }
    
    func testTrainDepartures() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITesting")
        app.launch()
        
        handleLocationDialog(app)
        
        // Ensure map is centered
        if app.buttons["CenterStationButton"].exists {
            app.buttons["CenterStationButton"].tap()
        }
        
        let stationButton = app.buttons["TrainStation_HSL_STATION_HKI"]
        if stationButton.waitForExistence(timeout: 10) {
            stationButton.tap()
            
            assertElementExists(app, identifier: "DepartureRow_I", timeout: 15)
            takeScreenshot(named: "Train_Departures")
        }
    }

    private func handleLocationDialog(_ app: XCUIApplication) {
        addUIInterruptionMonitor(withDescription: "Location Permission") { (alert) -> Bool in
            let allowButton = alert.buttons["Allow While Using App"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
        
        // Interact to trigger monitor if alert is pending
        app.tap()
        
        // Remove monitor after robust handling to avoid side effects?
        // Actually keep it as standard practice or remove if single-fire.
        // For simple tests, we leave it or relying on the first tap.
    }
    
    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addLine550IfNeeded(_ app: XCUIApplication) {
        let lineToggle = findLineToggle(app, identifier: "LineToggle_HSL_2550")
        if lineToggle.exists {
            ensureLineSelected(lineToggle)
            return
        }

        let addButton = app.buttons["AddLineButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("550")

        let row = app.otherElements["LineSearchRow_HSL_2550"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let toggleButton = row.buttons["LineSearchToggle_HSL_2550"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 5))
        toggleButton.tap()
        dismissLineSearchSheetIfNeeded(app)
        assertLineSearchSheetDismissed(app)
        XCTAssertTrue(lineToggle.waitForExistence(timeout: 10))
        ensureLineSelected(lineToggle)
    }

    private func dismissLineSearchSheetIfNeeded(_ app: XCUIApplication) {
        // 1) Clear search / dismiss keyboard first
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            // Common labels: "Clear text", "Clear", or the clear button inside the search field
            if searchField.buttons["Clear text"].exists {
                searchField.buttons["Clear text"].tap()
            } else if searchField.buttons["Clear"].exists {
                searchField.buttons["Clear"].tap()
            }
        }

        // 2) Dismiss keyboard if still visible
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            if keyboard.buttons["Hide keyboard"].exists {
                keyboard.buttons["Hide keyboard"].tap()
            } else if keyboard.buttons["Done"].exists {
                keyboard.buttons["Done"].tap()
            } else {
                // Fallback: tap outside to try to dismiss
                app.tap()
            }
        }
        // 3) Prefer the sheet's nav bar Close button
        if app.navigationBars.buttons["Close"].exists {
            app.navigationBars.buttons["Close"].tap()
        }

        // 4) Dismiss sheet via a simple swipe (fallback)
        var attempts = 0
        while attempts < 4 {
            let sheet = app.otherElements["LineSearchSheet"]
            if !sheet.exists { break }
            sheet.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            attempts += 1
        }

        // 5) Wait for the main control to reappear as a sign the sheet is gone
        _ = app.buttons["AddLineButton"].waitForExistence(timeout: 3)
    }

    private func assertLineSearchSheetDismissed(_ app: XCUIApplication) {
        if app.otherElements["LineSearchSheet"].exists {
            XCTFail("LineSearchSheet still visible after dismiss")
        }
    }

    // Simple swipeDown is preferred for sheet dismiss.

    // Drag-to-dismiss intentionally avoided; prefer sheet dismiss button.

    private func assertElementExists(_ app: XCUIApplication, identifier: String, timeout: TimeInterval) {
        let any = app.descendants(matching: .any)[identifier]
        if any.waitForExistence(timeout: timeout) {
            return
        }

        let candidates: [XCUIElement] = [
            app.otherElements[identifier],
            app.cells[identifier],
            app.buttons[identifier],
            app.staticTexts[identifier]
        ]
        for element in candidates {
            if element.waitForExistence(timeout: 2) {
                return
            }
        }

        let debugAttachment = XCTAttachment(string: app.debugDescription)
        debugAttachment.name = "DebugDescription_\(identifier)"
        debugAttachment.lifetime = .keepAlways
        add(debugAttachment)

        let screenshot = XCUIScreen.main.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: screenshot)
        screenshotAttachment.name = "Missing_\(identifier)"
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)

        XCTFail("Missing element: \(identifier)")
    }

    private func openDeparturesSheet(_ app: XCUIApplication, button: XCUIElement) {
        for _ in 0..<3 {
            if waitForHittable(button, timeout: 5) {
                button.tap()
            }
            // List can be otherElements, tables, or collectionViews depending on iOS version
            let list = app.descendants(matching: .any)["DeparturesList"]
            if list.waitForExistence(timeout: 5) {
                return
            }
            sleep(1)
        }
        XCTFail("Departures sheet did not open")
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func findLineToggle(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        let lineToggle = app.buttons[identifier]
        if lineToggle.exists {
            return lineToggle
        }

        let scroll = app.scrollViews["LineToggleScroll"]
        if scroll.exists {
            for _ in 0..<4 {
                scroll.swipeLeft()
                if lineToggle.exists { return lineToggle }
            }
            for _ in 0..<4 {
                scroll.swipeRight()
                if lineToggle.exists { return lineToggle }
            }
        }

        return lineToggle
    }

    private func ensureLineSelected(_ lineToggle: XCUIElement) {
        if lineToggle.isSelected { return }
        if let value = lineToggle.value as? String, value == "Selected" { return }
        lineToggle.tap()
    }
}
