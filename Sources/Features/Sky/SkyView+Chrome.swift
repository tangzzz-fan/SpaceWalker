import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

extension SkyView {
    // MARK: - 外壳

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    /// 竖屏：状态条与底部三段由 ContentView 统一提供，这里只放信息卡。
    var portraitOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                activeCards
            }
        }
        .padding(.horizontal, ChromeTokens.edgePadding)
        .padding(.bottom, ChromeTokens.horizontalPadding)
    }

    /// 横屏：高度只剩 390pt，顶栏和卡片不能都往下堆。
    /// 顶栏压成一行胶囊留在左上，卡片改挂在右侧竖栏，中间视场留空。
    var landscapeOverlay: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    compactTopBar
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 8) {
                        activeCards
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(width: 340)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    /// 横屏顶栏只留最要紧的：坐标、时刻、当前天区。
    /// 「姿态跟随 / 拖动旋转」这类说明交给底栏状态，不再占一整行。
    var compactTopBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("星图")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(compactSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if session.observer.isOn, !session.observer.hasHeading {
                    Button {
                        calibrateFacingNorth()
                    } label: {
                        Image(systemName: "location.north.line")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("手机水平朝正北时点此")
                }
                if let region = session.currentRegion {
                    Button {
                        openRegion(region)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: regionSymbol(region))
                            Text(region.title)
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("当前天区 \(region.title)，查看来头")
                }
            }
            if session.observer.stage == .ready {
                timeScrubber
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    var compactSubtitle: String {
        if session.isManual {
            return "拖动旋转"
        }
        guard session.observer.stage == .ready,
              let latitude = session.observer.latitude,
              let longitude = session.observer.longitude,
              let sidereal = session.observer.currentSiderealDegrees()
        else {
            return "姿态跟随"
        }
        let base = String(format: "%.1f°N %.1f°E · 恒星时 %.1f°", latitude, longitude, sidereal)
        return session.observer.clock.isNow ? base : "\(base) · \(timeOffsetLabel)"
    }

    func openRegion(_ region: SkyRegion) {
        switch region {
        case .constellation(let info):
            session.infoRegion = info
        case .pattern(let pattern):
            session.identifiedPattern = pattern
        }
    }

    /// 转屏时留一行尺寸，排查排版时不用猜当时是哪个方向。
    func logLayout(_ size: CGSize) {
        SessionLog.append(
            String(format: "sky.layout %.0fx%.0f %@", size.width, size.height, isLandscape ? "landscape" : "portrait")
        )
    }

    var crosshair: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 1)
                .frame(width: 44, height: 44)
            DwellRing(hud: hud)
            Circle()
                .fill(.white.opacity(0.75))
                .frame(width: 3, height: 3)
        }
        .allowsHitTesting(false)
    }

    func regionSymbol(_ region: SkyRegion) -> String {
        switch region {
        case .constellation: "book.closed"
        case .pattern: "triangle"
        }
    }

    var timeScrubber: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
            Slider(value: timeOffsetBinding, in: -12...12) { editing in
                guard !editing else { return }
                session.tonightStamp = 0
                refreshTonight()
            }
            .controlSize(.mini)
            .frame(width: 140)
            Text(timeOffsetLabel)
                .font(.caption2.monospacedDigit())
                .frame(width: 52, alignment: .leading)
            Button {
                session.observer.resetClock()
                refreshField()
                refreshTonight()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .opacity(session.observer.clock.isNow ? 0.3 : 1)
            .accessibilityLabel("时间回到此刻")
        }
        .padding(.top, 2)
    }

    var timeOffsetBinding: Binding<Double> {
        Binding(
            get: { session.observer.timeOffsetHours },
            set: { hours in
                session.observer.setTimeOffset(hours: hours)
                refreshField()
                refreshTonight()
            }
        )
    }

    var timeOffsetLabel: String {
        let hours = session.observer.timeOffsetHours
        if session.observer.clock.isNow {
            return "此刻"
        }
        let minutes = Int((hours * 60).rounded())
        let sign = minutes < 0 ? "-" : "+"
        let magnitude = abs(minutes)
        return String(format: "%@%d:%02d", sign, magnitude / 60, magnitude % 60)
    }

    var layerLabel: String {
        var parts: [String] = []
        if session.showsConstellations { parts.append("line") }
        if session.showsOutlines { parts.append("outline") }
        if session.showsAsterisms { parts.append("asterism") }
        if session.showsPatterns { parts.append("pattern") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }
}
