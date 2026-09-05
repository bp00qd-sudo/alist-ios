import BackgroundTasks
import CoreLocation
import Foundation

final class BackgroundKeepAliveController: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var enabled = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 1000
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        if value {
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.startUpdatingLocation()
            scheduleProcessingTask()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }

    private func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: "com.alist.ios.processing")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if enabled { manager.startUpdatingLocation() }
    }
}
