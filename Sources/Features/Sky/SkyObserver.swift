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

    private static let goodAccuracy: Double = 15
    private static let fallbackDelay: TimeInterval = 10

    private let manager = CLLocationManager()
    private var calibratingHeading: Double?
    private var headingIsTrueNorth = false
    private var headingAccuracy: Double = -1
    private var bestHeadingAccuracy: Double = .infinity
    private var manualLabel: String?
    private var lockedManually = false
    private var lockedWithMagneticNorth = false
    private var lockedAccuracy: Double = -1
    private var enabledAt: TimeInterval = 0
    private var isStarted = false
    private var headingLogCount = 0

    private(set) var stage: Stage = .off
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var northOffsetDegrees: Double?
    private(set) var hasHeading = false
    private(set) var clock = SkyClock()

    var timeOffsetHours: Double { clock.offsetHours }

    var isOn: Bool {
        stage != .off
    }

    var statusText: String {
        switch stage {
        case .off: return "赤道坐标（未对齐今夜）"
        case .requesting: return "正在获取位置…"
        case .ready:
            guard hasHeading else {
                if bestHeadingAccuracy < .infinity {
                    return String(format: "今夜此刻 · 时间已对齐，磁力计精度 %.0f° 不足以定方位（试试画 8 字或离开金属）", bestHeadingAccuracy)
                }
                return "今夜此刻 · 时间已对齐，方位未校准"
            }
            if let manualLabel, lockedManually {
                return "今夜此刻 · 已按 \(manualLabel) 校准方位"
            }
            if lockedWithMagneticNorth {
                return String(format: "今夜此刻 · 磁北对齐（±%.0f°），远离金属可转真北", lockedAccuracy)
            }
            return "今夜此刻 · 时间与方位已对齐"
        case .denied: return "定位被拒绝 · 仍显示赤道坐标"
        case .unavailable: return "定位不可用 · 仍显示赤道坐标"
        }
    }

    func enable() {
        guard stage == .off || stage == .denied else { return }
        stage = .requesting
        enabledAt = ProcessInfo.processInfo.systemUptime
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
        lockedWithMagneticNorth = false
        lockedManually = false
        manualLabel = nil
        bestHeadingAccuracy = .infinity
        calibratingHeading = nil
    }

    func currentSiderealDegrees() -> Double? {
        guard let longitude else { return nil }
        return Astronomy.localSiderealDegrees(
            julianDay: Astronomy.julianDay(shiftedNow()),
            longitude: longitude
        )
    }

    func shiftedNow() -> Date {
        clock.instant()
    }

    func setTimeOffset(hours: Double) {
        clock.setOffset(hours: hours)
    }

    func applySimulatedLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        stage = .ready
        SessionLog.append(
            String(format: "sky.align simulated location=%.3f,%.3f", latitude, longitude)
        )
    }

    func resetClock() {
        clock.reset()
    }

    func calibrateAgainst(starAzimuth: Double, sceneAzimuth: Double, label: String) {
        guard stage == .ready else { return }
        northOffsetDegrees = Astronomy.fieldRotationDegrees(trueHeading: starAzimuth, sceneAzimuth: sceneAzimuth)
        lockedManually = true
        manualLabel = label
        lockedAccuracy = 0
        lockedWithMagneticNorth = false
        hasHeading = true
        SessionLog.append(
            String(
                format: "sky.align manual star=%@ starAz=%.1f sceneAz=%.1f offset=%.1f",
                label,
                starAzimuth,
                sceneAzimuth,
                northOffsetDegrees ?? 0
            )
        )
    }

    @discardableResult
    func calibrate(sceneAzimuth: Double) -> Bool {
        guard !lockedManually else { return false }
        guard stage == .ready, let heading = calibratingHeading else { return false }
        let waited = ProcessInfo.processInfo.systemUptime - enabledAt
        let firstLock = northOffsetDegrees == nil && (headingAccuracy <= Self.goodAccuracy || waited > Self.fallbackDelay)
        let trueNorthUpgrade = northOffsetDegrees != nil && lockedWithMagneticNorth && headingIsTrueNorth
        let accuracyUpgrade = northOffsetDegrees != nil && lockedAccuracy > 10 && headingAccuracy <= 10
        guard firstLock || trueNorthUpgrade || accuracyUpgrade else { return false }

        let offset = Astronomy.fieldRotationDegrees(trueHeading: heading, sceneAzimuth: sceneAzimuth)
        northOffsetDegrees = offset
        lockedAccuracy = headingAccuracy
        lockedWithMagneticNorth = !headingIsTrueNorth
        hasHeading = true
        SessionLog.append(
            String(
                format: "sky.align heading=%.1f(%@) accuracy=%.1f azimuth=%.1f offset=%.1f",
                heading,
                headingIsTrueNorth ? "true" : "magnetic",
                headingAccuracy,
                sceneAzimuth,
                offset
            )
        )
        return true
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
        let headingAvailable = CLLocationManager.headingAvailable()
        if headingAvailable {
            manager.startUpdatingHeading()
        }
        SessionLog.append("sky.align started headingAvailable=\(headingAvailable)")
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
        if headingLogCount < 3 {
            headingLogCount += 1
            SessionLog.append(
                String(format: "sky.align heading=%.1f mag=%.1f acc=%.1f", trueHeading, magneticHeading, accuracy)
            )
        }
        bestHeadingAccuracy = min(bestHeadingAccuracy, max(accuracy, 0))
        guard accuracy >= 0, accuracy <= 25 else { return }
        headingAccuracy = accuracy

        if trueHeading >= 0 {
            calibratingHeading = trueHeading
            headingIsTrueNorth = true
        } else if calibratingHeading == nil || !headingIsTrueNorth {
            calibratingHeading = magneticHeading
            headingIsTrueNorth = false
        }
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
