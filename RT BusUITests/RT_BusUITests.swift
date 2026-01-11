//
//  RT_BusUITests.swift
//  RT BusUITests
//
//  Created by Automation on 30.12.2025.
//

import XCTest

final class RT_BusUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainMap() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITesting")
        app.launch()
        
        handleLocationDialog(app)
        
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
        let resultStaticText = app.staticTexts["550"] // Assuming search result displays the number
        // Wait longer for network
        if resultStaticText.waitForExistence(timeout: 10) {
            // Success
            takeScreenshot(named: "Search_Results")
        }
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
        
        let departuresButton = app.buttons["DeparturesButton"]
        if departuresButton.waitForExistence(timeout: 5) {
            departuresButton.tap()
            
            let title = app.staticTexts["Rautatientori"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
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
        
        let trainsButton = app.buttons["TrainDeparturesButton"]
        if trainsButton.waitForExistence(timeout: 5) {
            trainsButton.tap()
            
            let title = app.staticTexts["Helsinki Central"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
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
}
