import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

extension SkyView {
    // MARK: - 运行时

    @MainActor
    func load() async {
        if session.catalog == nil {
            let started = ProcessInfo.processInfo.systemUptime
            let loaded = StarCatalog.loadFromBundle()
            session.catalog = loaded
            session.groups = SkyGroupIndex.groups(stars: loaded?.stars ?? [])
            refreshTonight()
            SessionLog.append(
                String(
                    format: "sky.catalog stars=%d elapsedMs=%.0f",
                    loaded?.stars.count ?? 0,
                    (ProcessInfo.processInfo.systemUptime - started) * 1000
                )
            )
        }
        if LaunchMode.asterismBrowserOnLaunch(environment: ProcessInfo.processInfo.environment) {
            showsAsterismBrowser = true
        }
        startMotion()
        if let location = LaunchMode.simulatedLocation(environment: ProcessInfo.processInfo.environment) {
            session.observer.applySimulatedLocation(latitude: location.latitude, longitude: location.longitude)
        } else if LaunchMode.autoAlignEnabled(environment: ProcessInfo.processInfo.environment), !session.observer.isOn {
            session.observer.enable()
        }
        if let hours = LaunchMode.timeOffsetHours(environment: ProcessInfo.processInfo.environment) {
            session.observer.setTimeOffset(hours: hours)
            refreshField()
        }
        if LaunchMode.asterismsEnabled(environment: ProcessInfo.processInfo.environment) {
            session.showsAsterisms = true
            scene.setAsterismsVisible(true)
        }
        if LaunchMode.outlinesEnabled(environment: ProcessInfo.processInfo.environment) {
            session.showsOutlines = true
            scene.setSilhouettesVisible(true)
        }
        if LaunchMode.allLayersEnabled(environment: ProcessInfo.processInfo.environment) {
            session.showsConstellations = true
            session.showsOutlines = true
            session.showsAsterisms = store.state.flags.cultureEnabled
            session.showsPatterns = store.state.flags.deepEnabled
            scene.setConstellationsVisible(true)
            scene.setSilhouettesVisible(true)
            scene.setAsterismsVisible(true)
            scene.setPatternsVisible(true)
        }
        if let raw = LaunchMode.patternPreview(environment: ProcessInfo.processInfo.environment) {
            session.showsPatterns = true
            scene.setPatternsVisible(true)
            let id = raw == "1" ? SkyPatternCatalog.all.first?.id : raw
            if let id {
                for _ in 0..<60 where scene.direction(forPattern: id) == nil {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                if let direction = scene.direction(forPattern: id) {
                    session.aim(at: direction)
                    SessionLog.append("sky.aim pattern=\(id)")
                }
            }
        }
        if LaunchMode.finderPreviewEnabled(environment: ProcessInfo.processInfo.environment)
            || LaunchMode.tourPreviewEnabled(environment: ProcessInfo.processInfo.environment)
            || LaunchMode.fengshenTarget(environment: ProcessInfo.processInfo.environment) != nil {
            showsFinder = true
        }
        if LaunchMode.dwellProbeEnabled(environment: ProcessInfo.processInfo.environment) {
            session.track(Task {
                while !Task.isCancelled {
                    stepDwell()
                    try? await Task.sleep(for: .milliseconds(80))
                }
            })
        }
        if let abbreviation = LaunchMode.regionPreview(environment: ProcessInfo.processInfo.environment),
           let region = ConstellationInfo.region(for: abbreviation, in: session.catalog?.stars ?? []) {
            session.currentRegion = .constellation(region)
            try? await Task.sleep(for: .seconds(2))
            session.infoRegion = region
        }
        if let title = LaunchMode.groupPreview(environment: ProcessInfo.processInfo.environment),
           let stars = session.catalog?.stars {
            let matched = SkyGroupIndex.groups(stars: stars)
            if let group = matched.first(where: { $0.title == title })
                ?? SkyGroupIndex.search(matched, query: title).first {
                try? await Task.sleep(for: .milliseconds(600))
                focus(group: group)
            }
        }
        if let fov = LaunchMode.fieldOfView(environment: ProcessInfo.processInfo.environment) {
            for _ in 0..<40 where !scene.isReady {
                try? await Task.sleep(for: .milliseconds(50))
            }
            session.setFieldOfView(fov)
            SessionLog.append(String(format: "sky.fov value=%.1f", scene.fieldOfView))
        }
        if let abbreviation = LaunchMode.aimTarget(environment: ProcessInfo.processInfo.environment),
           let stars = session.catalog?.stars {
            // 用骨架星求中心，不用该星座的全部成员：仙后座有几十颗暗成员，
            // 平均下来会偏出 W 一大截，截图里形状就不居中了。
            let keys = Set(
                Constellations.all
                    .first { $0.abbreviation == abbreviation }?
                    .lines.flatMap { [$0.first, $0.second] } ?? []
            )
            let members = keys.isEmpty
                ? stars.filter { $0.constellation == abbreviation }
                : stars.filter { keys.contains($0.key) }
            if !members.isEmpty {
                // 用最小覆盖圆求中心：形状再偏，定位过去也整块落在视场里。
                let center = SkyPicker.enclosingCenter(of: members.map(SkyPicker.direction(for:)))
                for _ in 0..<40 where !scene.isReady {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                if let center {
                    session.aim(at: center)
                }
                SessionLog.append("sky.aim target=\(abbreviation) stars=\(members.count)")
            }
        }
        if let abbreviation = LaunchMode.constellationPreview(environment: ProcessInfo.processInfo.environment),
           let constellation = Constellations.all.first(where: { $0.abbreviation == abbreviation }) {
            // 高亮要等场景建完：星座位置表是 build 阶段填的，早一步调就是空表，
            // 卡片弹了、天上却没亮线。
            for _ in 0..<40 where !scene.isReady {
                try? await Task.sleep(for: .milliseconds(50))
            }
            session.identifiedConstellation = constellation
            scene.highlightConstellation(abbreviation)
            SessionLog.append("sky.constellation preview=\(abbreviation)")
        }
        if let name = LaunchMode.starPreview(environment: ProcessInfo.processInfo.environment),
           let star = session.catalog?.stars.first(where: { $0.name == name }) {
            session.selected = star
        }
        if let target = LaunchMode.guideTarget(environment: ProcessInfo.processInfo.environment) {
            let stars = session.catalog?.stars ?? []
            if let star = stars.first(where: { $0.name == target }) {
                startGuide(to: star)
            }
        }
        if LaunchMode.perfLogEnabled(environment: ProcessInfo.processInfo.environment) {
            let showsHUD = LaunchMode.fpsHUDEnabled(environment: ProcessInfo.processInfo.environment)
            session.track(Task {
                var loggedBudget = false
                while !Task.isCancelled {
                    if !loggedBudget, scene.isReady {
                        loggedBudget = true
                        SessionLog.append(scene.budget())
                    }
                    let summary = session.perf.tick(
                        now: ProcessInfo.processInfo.systemUptime,
                        layers: layerLabel
                    )
                    if showsHUD { perfSummary = summary }
                    try? await Task.sleep(for: .seconds(1))
                }
            })
        }
    }

    func startMotion() {
        guard LaunchMode.skyMotionEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        session.startMotion {
            if session.observer.calibrate(sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField)) {
                refreshField()
            }
            stepDwell()
        }
    }

    func toggleAlignment() {
        if session.observer.isOn {
            session.observer.disable()
            SessionLog.append("sky.align off")
        } else {
            session.observer.enable()
        }
        refreshField()
        refreshTonight()
    }

    func refreshField() {
        guard let orientation = session.observer.fieldOrientation() else {
            scene.setField(orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
            return
        }
        scene.setField(orientation: orientation)
    }

    func horizontal(for star: Star) -> Astronomy.Horizontal? {
        guard session.observer.stage == .ready,
              let latitude = session.observer.latitude,
              let sidereal = session.observer.currentSiderealDegrees()
        else {
            return nil
        }
        return Astronomy.horizontal(
            rightAscensionHours: star.rightAscensionHours,
            declinationDegrees: star.declinationDegrees,
            siderealDegrees: sidereal,
            latitude: latitude
        )
    }

    func stepDwell() {
        guard scene.isReady else { return }
        let frameNow = ProcessInfo.processInfo.systemUptime
        if frameNow - session.regionStamp > 0.5 {
            session.regionStamp = frameNow
            let region = scene.currentRegion()
            if region?.key != session.currentRegion?.key {
                SessionLog.append(
                    String(
                        format: "sky.region name=%@ distance=%.1f",
                        region?.key ?? "none",
                        region?.distance ?? -1
                    )
                )
            }
            session.currentRegion = region
        }
        if let target = session.guide {
            let vector = scene.guideVector(to: target)
            session.guideVector = vector
            guard let vector, vector.isAligned else { return }
            session.selected = target
            session.guide = nil
            session.guideVector = nil
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            SessionLog.append("sky.guide arrived=\(target.name)")
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let candidates = scene.candidates(along: scene.viewDirectionInField)
        if candidates.star == nil, now - diagnosticsStamp > 1.5,
           LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) {
            diagnosticsStamp = now
            SessionLog.append(scene.pickDiagnostics())
        }

        let step = session.attention.step(
            now: now,
            candidates: AttentionArbiter.Candidates(
                star: candidates.star,
                constellation: candidates.constellation?.abbreviation,
                pattern: session.showsPatterns ? candidates.pattern?.id : nil,
                asterism: store.state.flags.cultureEnabled ? candidates.asterism?.name : nil
            )
        )
        react(to: step, candidates: candidates)
        hud.show(step.progress)
    }

    func react(to step: AttentionArbiter.Step, candidates: SkyScene.Candidates) {
        for effect in step.effects {
            switch effect {
            case .highlight(let target):
                switch target {
                case .constellation(let key):
                    scene.highlightConstellation(key)
                case .pattern(let id):
                    scene.highlightPattern(id)
                case .asterism(let id):
                    scene.highlightAsterism(id)
                case .star, .none:
                    scene.highlightConstellation(nil)
                    scene.highlightPattern(nil)
                    scene.highlightAsterism(nil)
                    session.identifiedConstellation = nil
                    session.identifiedPattern = nil
                    session.identifiedAsterism = nil
                }
            case .confirmed(let target):
                switch target {
                case .star(let star):
                    session.selected = star
                    session.selectedGroup = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    SessionLog.append(
                        String(
                            format: "sky.dwell name=%@ mag=%.2f offset=%.1f",
                            star.name,
                            star.magnitude,
                            scene.aimOffsetDegrees(of: star)
                        )
                    )
                case .constellation(let key):
                    session.selected = nil
                    session.identifiedConstellation = candidates.constellation
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    SessionLog.append("sky.constellation dwell=\(key)")
                case .asterism(let name):
                    session.selected = nil
                    session.identifiedAsterism = candidates.asterism
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    SessionLog.append("sky.asterism dwell=\(name)")
                case .pattern(let id):
                    session.selected = nil
                    session.identifiedPattern = candidates.pattern
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    SessionLog.append("sky.pattern dwell=\(id)")
                }
            }
        }
    }

    func runPickProbe() async {
        guard LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        for _ in 0..<60 {
            let alignmentSettled = !session.observer.isOn
                || session.observer.stage == .ready
                || session.observer.stage == .denied
                || session.observer.stage == .unavailable
            if scene.isReady, alignmentSettled { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard scene.isReady else {
            SessionLog.append("sky.pickProbe skipped=not-ready")
            return
        }
        SessionLog.append(scene.pickRoundtrip())
    }
}
