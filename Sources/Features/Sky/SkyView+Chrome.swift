import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

extension SkyView {
    // MARK: - 外壳

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    /// 竖屏：顶栏在上，卡片与底栏依次叠在下方。
    var portraitOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            perfBadge(alignment: .trailing)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                activeCards
            }
            hintBar
                .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    /// 横屏：高度只剩 390pt，顶栏和卡片不能都往下堆。
    /// 顶栏压成一行胶囊留在左上，卡片改挂在右侧竖栏，中间视场留空。
    var landscapeOverlay: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    compactTopBar
                    perfBadge(alignment: .leading)
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
            // 横屏宽度富余，底栏按内容收紧居中；竖屏那条通栏胶囊在横屏会太空。
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                hintBar
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    func perfBadge(alignment: Alignment) -> some View {
        if let summary = perfSummary {
            Text(summary.fpsOnlyLine)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .frame(maxWidth: .infinity, alignment: alignment)
                .padding(.top, 6)
        }
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

    var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("星图")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(skySubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(session.isManual ? "手动 · 拖动旋转" : "姿态跟随 · 转动手机环顾")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(session.observer.statusText)
                .font(.caption2)
                .foregroundStyle(session.observer.isOn ? .primary : .secondary)
            if session.observer.stage == .ready {
                timeScrubber
            }
            if let region = session.currentRegion {
                Button {
                    openRegion(region)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: regionSymbol(region))
                        Text("当前天区 \(region.title) · 查看来头")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            if session.observer.isOn, !session.observer.hasHeading {
                Button {
                    calibrateFacingNorth()
                } label: {
                    Label("手机水平朝正北时点此", systemImage: "location.north.line")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    func regionSymbol(_ region: SkyRegion) -> String {
        switch region {
        case .constellation: "book.closed"
        case .pattern: "triangle"
        }
    }

    var skySubtitle: String {
        guard session.observer.stage == .ready,
              let latitude = session.observer.latitude,
              let longitude = session.observer.longitude,
              let sidereal = session.observer.currentSiderealDegrees()
        else {
            let stars = session.catalog?.stars ?? []
            let base = "\(stars.count) 颗恒星 · \(stars.filter(\.isSelectable).count) 颗可选中 · \(Constellations.all.count) 个星座"
            return store.state.flags.cultureEnabled ? "\(base) · \(AsterismCatalog.all.count) 个星官" : base
        }
        let base = String(format: "%.1f°N %.1f°E · 恒星时 %.1f°", latitude, longitude, sidereal)
        return session.observer.clock.isNow ? base : "\(base) · \(timeOffsetLabel)"
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

    var hintBar: some View {
        HStack(spacing: 8) {
            if session.isManual {
                Button {
                    session.resetOrientation()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("重置视角")
            }

            // 姿态可用才给这个开关：没有陀螺仪的机器只有手动一条路。
            if session.canFollowAttitude {
                Button {
                    session.setFollowsAttitude(!session.followsAttitude)
                } label: {
                    Image(systemName: session.followsAttitude ? "hand.draw" : "gyroscope")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel(session.followsAttitude ? "切到手动拖动" : "切到姿态跟随")
            }

            Spacer()

            Button {
                showsFinder = true
            } label: {
                Label("找星", systemImage: "magnifyingglass")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize()
            }
            .accessibilityLabel("搜索并定位一颗星")

            Menu {
                Toggle(isOn: $session.showsConstellations) {
                    Label("星座连线", systemImage: "link")
                }
                Toggle(isOn: $session.showsOutlines) {
                    Label("星座轮廓", systemImage: "square.on.circle")
                }
                if store.state.flags.deepEnabled {
                    Divider()
                    Toggle(isOn: $session.showsPatterns) {
                        Label("星群（大三角）", systemImage: "triangle")
                    }
                }
            } label: {
                Label(
                    "星座",
                    systemImage: session.showsPatterns
                        ? "triangle"
                        : (session.showsConstellations ? "link" : (session.showsOutlines ? "square.on.circle" : "link.badge.plus"))
                )
                .font(.caption2)
                .lineLimit(1)
                .fixedSize()
            }
            .accessibilityLabel("星座连线、轮廓与星群")

            if store.state.flags.cultureEnabled {
                Menu {
                    Toggle(isOn: $session.showsAsterisms) {
                        Label("显示星官连线", systemImage: "circle.grid.3x3")
                    }
                    Button {
                        showsAsterismBrowser = true
                    } label: {
                        Label("浏览星官", systemImage: "list.bullet")
                    }
                } label: {
                    Label("星官", systemImage: "circle.grid.3x3")
                        .font(.caption2)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(session.showsAsterisms ? Color(red: 0.94, green: 0.82, blue: 0.56) : .primary)
                }
                .accessibilityLabel("中国星官连线与目录")
            }

            Button {
                toggleAlignment()
            } label: {
                Label("今夜", systemImage: session.observer.isOn ? "location.fill" : "location")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize()
            }
            .accessibilityLabel("对齐今夜此刻的真实天空")

            Button {
                store.dispatch(.route(.solarSystem))
            } label: {
                Image(systemName: "sun.max")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("太阳系")

            Button {
                showsCredits = true
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("素材来源")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    /// 当前点亮了哪几层，写进 `sky.perf`，掉帧时能对上号。
    var layerLabel: String {
        var parts: [String] = []
        if session.showsConstellations { parts.append("line") }
        if session.showsOutlines { parts.append("outline") }
        if session.showsAsterisms { parts.append("asterism") }
        if session.showsPatterns { parts.append("pattern") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }
}
