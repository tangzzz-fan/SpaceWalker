import CoreLocation
import Foundation
import Observation
import simd

@MainActor
@Observable
final class SkyObserver: NSObject {
    enum Stage: Equatable {
        case off
        case requesting
        case ready
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var calibratingHeading: Double?
    private var isStarted = false

    private(set) var stage: Stage = .off
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var northOffsetDegrees: Double?
    private(set) var hasHeading = false

    var isOn: Bool {
        stage != .off
    }

    var statusText: String {
        switch stage {
        case .off: "赤道坐标（未对齐今夜）"
        case .requesting: "正在获取位置…"
        case .ready: hasHeading ? "今夜此刻 · 时间与方位已对齐" : "今夜此刻 · 时间已对齐，方位未校准"
        case .denied: "定位被拒绝 · 仍显示赤道坐标"
        case .unavailable: "定位不可用 · 仍显示赤道坐标"
        }
    }

    func enable() {
        guard stage == .off || stage == .denied else { return }
        stage = .requesting
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            start()
        case .denied, .restricted:
            stage = .denied
        @unknown default:
            stage = .unavailable
        }
    }

    func disable() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        stage = .off
        isStarted = false
        northOffsetDegrees = nil
        hasHeading = false
        calibratingHeading = nil
    }

    func currentSiderealDegrees() -> Double? {
        guard let longitude else { return nil }
        return Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(Date()),
            longitude: longitude
        )
    }

    func calibrate(sceneAzimuth: Double) {
        guard stage == .ready, northOffsetDegrees == nil, let heading = calibratingHeading else { return }
        let offset = Astronomy.fieldRotationDegrees(trueHeading: heading, sceneAzimuth: sceneAzimuth)
        northOffsetDegrees = offset
        hasHeading = true
        SessionLog.append(
            String(
                format: "sky.align heading=%.1f azimuth=%.1f offset=%.1f",
                heading,
                sceneAzimuth,
                offset
            )
        )
    }

    func fieldOrientation() -> simd_quatf? {
        guard stage == .ready, let latitude, let sidereal = currentSiderealDegrees() else { return nil }
        let equatorial = Astronomy.equatorialToHorizontalRotation(
            siderealDegrees: sidereal,
            latitude: latitude
        )
        guard let northOffsetDegrees else { return equatorial }
        return Astronomy.yawRotation(degrees: northOffsetDegrees) * equatorial
    }

    private func start() {
        guard !isStarted else { return }
        isStarted = true
        manager.requestLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        SessionLog.append("sky.align started")
    }

    fileprivate func consume(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        stage = .ready
        SessionLog.append(
            String(
                format: "sky.align location=%.3f,%.3f sidereal=%.2f",
                coordinate.latitude,
                coordinate.longitude,
                currentSiderealDegrees() ?? 0
            )
        )
    }

    fileprivate func consume(trueHeading: Double, magneticHeading: Double, accuracy: Double) {
        guard accuracy >= 0, accuracy <= 25 else { return }
        calibratingHeading = trueHeading >= 0 ? trueHeading : magneticHeading
    }
}

extension SkyObserver: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.start()
            case .denied, .restricted:
                self.stage = .denied
                SessionLog.append("sky.align denied")
            case .notDetermined:
                break
            @unknown default:
                self.stage = .unavailable
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.consume(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let trueHeading = newHeading.trueHeading
        let magneticHeading = newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.consume(trueHeading: trueHeading, magneticHeading: magneticHeading, accuracy: accuracy)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if self.stage != .ready {
                self.stage = .unavailable
                SessionLog.append("sky.align failed=\(error.localizedDescription)")
            }
        }
    }
}
