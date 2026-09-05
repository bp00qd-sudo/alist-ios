import AVFoundation
import BackgroundTasks
import CoreLocation
import Foundation

final class BackgroundKeepAliveController: NSObject, CLLocationManagerDelegate {
    private var audioPlayer: AVAudioPlayer?
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
            startAudioKeepAlive()
            locationManager.requestAlwaysAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.startUpdatingLocation()
            scheduleProcessingTask()
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
            locationManager.stopUpdatingLocation()
        }
    }

    private func startAudioKeepAlive() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            audioPlayer = try AVAudioPlayer(data: Self.silenceWAV())
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0
            audioPlayer?.play()
        } catch {
            // The app remains functional if iOS rejects the experimental mode.
        }
    }

    private func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: "com.alist.ios.processing")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func silenceWAV() -> Data {
        // One second, mono, 8 kHz, 16-bit PCM silence. It is tiny and avoids a
        // bundled audio asset solely for the opt-in keep-alive experiment.
        let sampleRate: UInt32 = 8_000
        let samples = Int(sampleRate)
        let pcmBytes = samples * 2
        var data = Data(capacity: 44 + pcmBytes)
        func appendASCII(_ value: String) { data.append(contentsOf: value.utf8) }
        func appendUInt32(_ value: UInt32) { data.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init)) }
        func appendUInt16(_ value: UInt16) { data.append(contentsOf: withUnsafeBytes(of: value.littleEndian, Array.init)) }
        appendASCII("RIFF"); appendUInt32(UInt32(36 + pcmBytes)); appendASCII("WAVEfmt ")
        appendUInt32(16); appendUInt16(1); appendUInt16(1); appendUInt32(sampleRate)
        appendUInt32(sampleRate * 2); appendUInt16(2); appendUInt16(16); appendASCII("data")
        appendUInt32(UInt32(pcmBytes)); data.append(contentsOf: repeatElement(0, count: pcmBytes))
        return data
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if enabled { manager.startUpdatingLocation() }
    }
}
