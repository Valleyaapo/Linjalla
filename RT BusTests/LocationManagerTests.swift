//
//  LocationManagerTests.swift
//  RT BusTests
//

import Testing
import CoreLocation
@testable import RT_Bus

final class MockLocationManager: LocationManaging {
    weak var delegate: CLLocationManagerDelegate?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers
    private(set) var didRequestAuthorization = false
    private(set) var didStartUpdating = false

    func requestWhenInUseAuthorization() {
        didRequestAuthorization = true
    }

    func startUpdatingLocation() {
        didStartUpdating = true
    }
}

@MainActor
@Suite(.serialized)
struct LocationManagerTests {
    @Test
    func requestAuthorizationNotDeterminedRequestsPermission() {
        let mock = MockLocationManager()
        mock.authorizationStatus = .notDetermined

        let manager = LocationManager(manager: mock)
        manager.requestAuthorization()

        #expect(mock.didRequestAuthorization)
        #expect(!mock.didStartUpdating)
    }

    @Test
    func requestAuthorizationWhenAuthorizedStartsUpdating() {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse

        let manager = LocationManager(manager: mock)
        manager.requestAuthorization()

        #expect(!mock.didRequestAuthorization)
        #expect(mock.didStartUpdating)
    }

    @Test
    func authorizationChangeUpdatesStateAndStartsUpdating() async throws {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationManager(manager: mock)

        manager.locationManagerDidChangeAuthorization(CLLocationManager())
        try await Task.sleep(for: .milliseconds(20))

        #expect(manager.authorizationStatus == .authorizedWhenInUse)
        #expect(mock.didStartUpdating)
    }

    @Test
    func didUpdateLocationsUpdatesLastLocation() async throws {
        let mock = MockLocationManager()
        let manager = LocationManager(manager: mock)
        let location = CLLocation(latitude: 60.17, longitude: 24.94)

        manager.locationManager(CLLocationManager(), didUpdateLocations: [location])
        try await Task.sleep(for: .milliseconds(20))

        #expect(manager.lastLocation?.coordinate.latitude == location.coordinate.latitude)
        #expect(manager.lastLocation?.coordinate.longitude == location.coordinate.longitude)
    }
}
