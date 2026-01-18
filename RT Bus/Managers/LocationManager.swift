import Foundation
import CoreLocation
import Combine
import OSLog

protocol LocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var desiredAccuracy: CLLocationAccuracy { get set }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
}

final class CLLocationManagerWrapper: NSObject, LocationManaging {
    private let manager = CLLocationManager()

    var delegate: CLLocationManagerDelegate? {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var desiredAccuracy: CLLocationAccuracy {
        get { manager.desiredAccuracy }
        set { manager.desiredAccuracy = newValue }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
}

final class LocationManager: NSObject, ObservableObject, @unchecked Sendable {
    private let manager: LocationManaging
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    init(manager: LocationManaging = CLLocationManagerWrapper()) {
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = self.manager.authorizationStatus
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.startUpdatingLocation()
            default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            Task { @MainActor in
                self.lastLocation = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.ui.error("Location error: \(error)")
    }
}
