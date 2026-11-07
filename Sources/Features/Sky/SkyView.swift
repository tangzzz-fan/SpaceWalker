import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

struct SkyView: View {
    @Environment(Store<AppState, AppAction>.self) private var store

    @State private var scene = SkyScene()
    @State private var catalog: StarCatalog?
    @State private var rig = SkyRig()
    @State private var attitude = DeviceAttitude()
    @State private var lastDrag: CGSize = .zero
    @State private var selected: Star?
    @State private var selectedGroup: SkyGroup?
    @State private var groups: [SkyGroup] = []
    @State private var tonight: [TonightPick] = []
    @State private var motionActive = false
    @State private var showsCredits = false
    @State private var showsConstellations = true
    @State private var showsAsterisms = false
    @State private var showsOutlines = false
    @State private var showsPatterns = false
    @State private var identifiedConstellation: Constellation?
    @State private var constellationHold = ConstellationHold()
    @State private var constellationDismissed: String?
    @State private var identifiedPattern: SkyPattern?
    @State private var patternHold = ConstellationHold()
    @State private var patternDismissed: String?
    @State private var fengshenFocus: AsterismFocus?
    @State private var showsFinder = false
    @State private var guide: Star?
    @State private var guideVector: GuideVector?
    @State private var currentRegion: SkyRegion?
    @State private var infoRegion: ConstellationRegion?
    @State private var regionStamp: TimeInterval = 0
    @State private var dwell = DwellSelector()
    @State private var hud = DwellHUD()
    @State private var observer = SkyObserver()
    @State private var perf = SkyPerformanceProbe()
    @State private var perfSummary: ProbeSummary?
    @State private var diagnosticsStamp: TimeInterval = 0
    @State private var tonightStamp: TimeInterval = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if catalog != nil {
                GeometryReader { proxy in
                    reality
                        .onAppear { scene.resize(proxy.size) }
                        .onChange(of: proxy.size) { _, size in scene.resize(size) }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            crosshair

            VStack(alignment: .leading, spacing: 0) {
                topBar
                if let summary = perfSummary {
                    Text(summary.fpsOnlyLine)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)
                if let guide {
                    guideBar(guide)
                        .padding(.bottom, 10)
                }
                if let constellation = identifiedConstellation {
                    constellationBadge(constellation)
                        .padding(.bottom, 10)
                }
                if let pattern = identifiedPattern {
                    patternBadge(pattern)
                        .padding(.bottom, 10)
                }
                if let selectedGroup {
                    groupCard(selectedGroup)
                        .padding(.bottom, 10)
                }
                if let selected {
                    starCard(selected)
                        .padding(.bottom, 10)
                }
                hintBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
            await runPickProbe()
        }
        .onChange(of: showsConstellations) { _, visible in
            scene.setConstellationsVisible(visible)
        }
        .onChange(of: showsAsterisms) { _, visible in
            scene.setAsterismsVisible(visible)
        }
        .onChange(of: showsOutlines) { _, visible in
            scene.setSilhouettesVisible(visible)
        }
        .onChange(of: showsPatterns) { _, visible in
            scene.setPatternsVisible(visible)
            if !visible {
                resetPatternTracking()
            }
        }
        .onChange(of: selectedGroup) { _, group in
            scene.highlightAsterism(group?.asterismID)
        }
        .onChange(of: observer.stage) { _, _ in
            refreshField()
            refreshTonight()
        }
        .onDisappear {
            attitude.stop()
            observer.disable()
        }
        .sheet(isPresented: $showsCredits) { creditsSheet }
        .sheet(item: $infoRegion) { region in
            ConstellationInfoView(region: region, stars: catalog?.stars ?? []) { star in
                startGuide(to: star)
            }
        }
        .sheet(item: $fengshenFocus) { target in
            FengshenBoardView(focusAsterism: target.id) { asterism in
                fengshenFocus = nil
                if let group = SkyGroupIndex.group(forAsterism: asterism, in: groups) {
                    focus(group: group)
                }
            }
        }
        .sheet(isPresented: $showsFinder) {
            StarFinderView(
                stars: catalog?.stars ?? [],
                initialQuery: LaunchMode.finderQuery(environment: ProcessInfo.processInfo.environment),
                tonight: tonight,
                referenceDate: observer.shiftedNow(),
                initialTour: LaunchMode.tourPreviewEnabled(environment: ProcessInfo.processInfo.environment),
                initialFengshen: LaunchMode.fengshenTarget(environment: ProcessInfo.processInfo.environment),
                onPick: { star in startGuide(to: star) },
                onPickGroup: { group in focus(group: group) }
            )
        }
    }

    private var reality: some View {
        RealityView { content in
            content.camera = .virtual
            content.environment = .default
            guard let catalog else { return }
            scene.build(catalog: catalog)
            content.add(scene.root)
            scene.attach(content)
            if LaunchMode.perfLogEnabled(environment: ProcessInfo.processInfo.environment) {
                perf.attach(content)
            }
            scene.apply(rig: rig)
        } update: { _ in
            scene.apply(rig: rig)
        }
        .coordinateSpace(name: SkyScene.coordinateSpaceName)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard !motionActive else { return }
                    scene.releaseAim()
                    rig.drag(
                        deltaX: Float(value.translation.width - lastDrag.width),
                        deltaY: Float(value.translation.height - lastDrag.height)
                    )
                    lastDrag = value.translation
                }
                .onEnded { _ in lastDrag = .zero }
        )
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named(SkyScene.coordinateSpaceName))
                .onEnded { value in
                    let hit = scene.pick(at: value.location)
                    selected = hit
                    selectedGroup = nil
                    dwell.reset()
                    hud.show(0)
                    SessionLog.append("sky.select name=\(hit?.name ?? "none") mag=\(hit?.magnitude ?? 0)")
                }
        )
    }

    private var crosshair: some View {
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

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("星图")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(skySubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(motionActive ? "姿态跟随 · 转动手机环顾" : "拖动旋转（无陀螺仪时的降级）")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(observer.statusText)
                .font(.caption2)
                .foregroundStyle(observer.isOn ? .primary : .secondary)
            if observer.stage == .ready {
                timeScrubber
            }
            if let region = currentRegion {
                Button {
                    switch region {
                    case .constellation(let info):
                        infoRegion = info
                    case .pattern(let pattern):
                        identifiedPattern = pattern
                    }
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
            if observer.isOn, !observer.hasHeading {
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

    private func regionSymbol(_ region: SkyRegion) -> String {
        switch region {
        case .constellation: "book.closed"
        case .pattern: "triangle"
        }
    }

    private var skySubtitle: String {
        guard observer.stage == .ready,
              let latitude = observer.latitude,
              let longitude = observer.longitude,
              let sidereal = observer.currentSiderealDegrees()
        else {
            let stars = catalog?.stars ?? []
            return "\(stars.count) 颗恒星 · \(stars.filter(\.isSelectable).count) 颗可选中 · \(Constellations.all.count) 个星座 · \(AsterismCatalog.all.count) 个星官"
        }
        let base = String(format: "%.1f°N %.1f°E · 恒星时 %.1f°", latitude, longitude, sidereal)
        return observer.clock.isNow ? base : "\(base) · \(timeOffsetLabel)"
    }

    private var timeScrubber: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
            Slider(value: timeOffsetBinding, in: -12...12) { editing in
                guard !editing else { return }
                tonightStamp = 0
                refreshTonight()
            }
            .controlSize(.mini)
            .frame(width: 140)
            Text(timeOffsetLabel)
                .font(.caption2.monospacedDigit())
                .frame(width: 52, alignment: .leading)
            Button {
                observer.resetClock()
                refreshField()
                refreshTonight()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .opacity(observer.clock.isNow ? 0.3 : 1)
            .accessibilityLabel("时间回到此刻")
        }
        .padding(.top, 2)
    }

    private var timeOffsetBinding: Binding<Double> {
        Binding(
            get: { observer.timeOffsetHours },
            set: { hours in
                observer.setTimeOffset(hours: hours)
                refreshField()
                refreshTonight()
            }
        )
    }

    private var timeOffsetLabel: String {
        let hours = observer.timeOffsetHours
        if observer.clock.isNow {
            return "此刻"
        }
        let minutes = Int((hours * 60).rounded())
        let sign = minutes < 0 ? "-" : "+"
        let magnitude = abs(minutes)
        return String(format: "%@%d:%02d", sign, magnitude / 60, magnitude % 60)
    }

    private var hintBar: some View {
        HStack(spacing: 8) {
            if !motionActive {
                Button {
                    scene.releaseAim()
                    rig = SkyRig()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("重置视角")
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
                Toggle(isOn: $showsConstellations) {
                    Label("星座连线", systemImage: "link")
                }
                Toggle(isOn: $showsOutlines) {
                    Label("星座轮廓", systemImage: "square.on.circle")
                }
                Divider()
                Toggle(isOn: $showsPatterns) {
                    Label("星群（大三角）", systemImage: "triangle")
                }
            } label: {
                Label(
                    "星座",
                    systemImage: showsPatterns
                        ? "triangle"
                        : (showsConstellations ? "link" : (showsOutlines ? "square.on.circle" : "link.badge.plus"))
                )
                .font(.caption2)
                .lineLimit(1)
                .fixedSize()
            }
            .accessibilityLabel("星座连线、轮廓与星群")

            Button {
                showsAsterisms.toggle()
            } label: {
                Label("星官", systemImage: "circle.grid.3x3")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(showsAsterisms ? Color(red: 0.94, green: 0.82, blue: 0.56) : .primary)
            }
            .accessibilityLabel("中国星官连线")

            Button {
                toggleAlignment()
            } label: {
                Label("今夜", systemImage: observer.isOn ? "location.fill" : "location")
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

    private func guideBar(_ star: Star) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.fill")
                .font(.title3)
                .rotationEffect(.degrees(guideVector?.arrowDegrees ?? 0))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("前往 \(ChineseStarNames.chinese(for: star.name) ?? star.name)")
                    .font(.subheadline.weight(.medium))
                Text(guideVector?.instruction ?? "转动手机寻找…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                guide = nil
                guideVector = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("取消指路")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func startGuide(to star: Star) {
        guide = star
        guideVector = scene.guideVector(to: star)
        selected = nil
        selectedGroup = nil
        dwell.reset()
        hud.show(0)
        SessionLog.append("sky.guide start=\(star.name)")
    }

    private func refreshTonight() {
        guard observer.stage == .ready,
              let latitude = observer.latitude,
              let longitude = observer.longitude,
              !groups.isEmpty
        else {
            tonight = []
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - tonightStamp > 0.4 else { return }
        tonightStamp = now
        tonight = SkySeason.rank(
            groups: groups,
            stars: catalog?.stars ?? [],
            latitude: latitude,
            longitude: longitude
        )
    }

    private func focus(group: SkyGroup) {
        let stars = catalog?.stars ?? []
        guard let direction = SkyGroupIndex.anchor(group, stars: stars) else { return }
        scene.aim(at: direction)
        if group.isDrawable, !showsAsterisms {
            showsAsterisms = true
            scene.setAsterismsVisible(true)
        }
        selectedGroup = group
        selected = nil
        guide = nil
        guideVector = nil
        dwell.reset()
        hud.show(0)
        SessionLog.append("sky.group focus=\(group.id) members=\(group.memberCount)")
    }

    private func constellationBadge(_ constellation: Constellation) -> some View {
        let fact = ConstellationInfo.fact(for: constellation.abbreviation)
        let latin = ConstellationInfo.latinNames[constellation.abbreviation] ?? constellation.abbreviation
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "circle.dashed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(constellation.name)
                    .font(.headline)
                Text(latin)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Button {
                    infoRegion = ConstellationInfo.region(
                        for: constellation.abbreviation,
                        in: catalog?.stars ?? []
                    )
                } label: {
                    Image(systemName: "book.closed")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看星座来头")
            }
            if let fact {
                Text(fact.westernLore)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("\(constellation.starCount) 颗连线星 · 落在轮廓内 0.6 秒识别")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .padding(.trailing, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                identifiedConstellation = nil
                constellationDismissed = constellation.abbreviation
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func patternBadge(_ pattern: SkyPattern) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "triangle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(pattern.name)
                    .font(.headline)
                Text(pattern.latin)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
            }
            Text(pattern.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(pattern.season) · \(pattern.starCount) 颗锚星 · 落在星群内 0.6 秒识别")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .padding(.trailing, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                identifiedPattern = nil
                patternDismissed = pattern.id
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func groupCard(_ group: SkyGroup) -> some View {
        let stars = catalog?.stars ?? []
        let members = SkyGroupIndex.members(group, stars: stars)
        let brightest = SkyGroupIndex.brightest(group, stars: stars)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(group.title)
                    .font(.headline)
                Text(group.kind.label)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.18), in: Capsule())
                Spacer()
                Text(group.isDrawable ? "\(group.memberCount) 颗 · \(group.lineCount) 段" : "\(group.memberCount) 颗")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            if let line = group.fengshenLine {
                Button {
                    fengshenFocus = AsterismFocus(id: group.title)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "scroll")
                            .font(.system(size: 9))
                        Text(line)
                            .font(.caption2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("在封神星榜中查看 \(line)")
            }
            if let brightest {
                Text(String(format: "最亮 %@ · 视星等 %.2f", StarDisplay.make(for: brightest).title, brightest.magnitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let coordinate = SkySeason.coordinate(group, stars: stars) {
                let months = SkySeason.bestMonths(rightAscensionHours: coordinate.rightAscension)
                Text("最佳观赏 \(SkySeason.label(months))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let latitude = observer.latitude, let sidereal = observer.currentSiderealDegrees() {
                    let horizontal = Astronomy.horizontal(
                        rightAscensionHours: coordinate.rightAscension,
                        declinationDegrees: coordinate.declination,
                        siderealDegrees: sidereal,
                        latitude: latitude
                    )
                    Text(String(format: "此刻 高度 %.0f° · %@", horizontal.altitude, SkySeason.directionLabel(azimuth: horizontal.azimuth)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(members, id: \.name) { member in
                    Button {
                        selected = member
                        selectedGroup = nil
                        dwell.reset()
                        hud.show(0)
                    } label: {
                        Text(StarDisplay.make(for: member).title)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
            if let brightest {
                Button {
                    startGuide(to: brightest)
                } label: {
                    Label("指路到 \(StarDisplay.make(for: brightest).title)", systemImage: "location.north.line")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .padding(.trailing, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                selectedGroup = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func starCard(_ star: Star) -> some View {
        let display = StarDisplay.make(for: star)
        let nearby = SkyPicker.nearby(to: star, in: catalog?.stars ?? [])
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(display.title)
                    .font(.headline)
                if display.official {
                    Text("IAU")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                if let subtitle = display.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(display.constellation.isEmpty ? "—" : display.constellation)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            if let line = display.asterismLine {
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let line = display.mansionLine {
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let line = display.fengshenLine, let asterism = display.asterism?.name {
                Button {
                    fengshenFocus = AsterismFocus(id: asterism)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "scroll")
                            .font(.system(size: 9))
                        Text(line)
                            .font(.caption2)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("在封神星榜中查看 \(line)")
            }
            Text(String(format: "视星等 %.2f · 赤经 %.2fh · 赤纬 %.1f°", star.magnitude, star.rightAscensionHours, star.declinationDegrees))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let horizontal = horizontal(for: star) {
                Text(String(format: "高度 %.1f° · 方位 %.1f°（此刻）", horizontal.altitude, horizontal.azimuth))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !nearby.isEmpty {
                HStack(spacing: 6) {
                    Text("附近")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(nearby, id: \.name) { item in
                        Button {
                            selected = item
                            dwell.reset()
                            hud.show(0)
                            SessionLog.append("sky.nearby pick=\(item.name)")
                        } label: {
                            Text(StarDisplay.make(for: item).title)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            if let horizontal = horizontal(for: star) {
                alignmentButton(star: star, azimuth: horizontal.azimuth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .padding(.trailing, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                selected = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func alignmentButton(star: Star, azimuth: Double) -> some View {
        let offset = aimOffset(for: star)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                calibrate(using: star, azimuth: azimuth)
            } label: {
                Label("以该星校准方位", systemImage: "scope")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(offset > 3)

            if offset > 3 {
                Text(String(format: "先把该星移到准星中心再校准（当前偏差 %.0f°）", offset))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func aimOffset(for star: Star) -> Double {
        scene.aimOffsetDegrees(of: star)
    }

    private func calibrateFacingNorth() {
        observer.calibrateAgainst(
            starAzimuth: 0,
            sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField),
            label: "正北"
        )
        refreshField()
    }

    private func calibrate(using star: Star, azimuth: Double) {
        observer.calibrateAgainst(
            starAzimuth: azimuth,
            sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField),
            label: star.name
        )
        refreshField()
    }

    private var creditsSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("数据来源")
                    .font(.title3.weight(.semibold))
                Text("恒星数据：HYG Database v4.1（CC BY-SA 4.0），由 Hipparcos、Yale BSC、Glise 等编目汇编。本次仅取视星等 ≤ 4.5 或有专名的 1102 颗。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("星官与连线：Stellarium 中国星空文化（CC BY-SA），301 个星官、814 段连线。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("坐标系：J2000 赤道坐标，尚未做时间与地理位置的周日旋转对齐。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("本页数据以 CC BY-SA 4.0 提供，衍生子集同样适用该许可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func load() async {
        if catalog == nil {
            let started = ProcessInfo.processInfo.systemUptime
            let loaded = StarCatalog.loadFromBundle()
            catalog = loaded
            groups = SkyGroupIndex.groups(stars: loaded?.stars ?? [])
            refreshTonight()
            SessionLog.append(
                String(
                    format: "sky.catalog stars=%d elapsedMs=%.0f",
                    loaded?.stars.count ?? 0,
                    (ProcessInfo.processInfo.systemUptime - started) * 1000
                )
            )
        }
        startMotion()
        if let location = LaunchMode.simulatedLocation(environment: ProcessInfo.processInfo.environment) {
            observer.applySimulatedLocation(latitude: location.latitude, longitude: location.longitude)
        } else if LaunchMode.autoAlignEnabled(environment: ProcessInfo.processInfo.environment), !observer.isOn {
            observer.enable()
        }
        if let hours = LaunchMode.timeOffsetHours(environment: ProcessInfo.processInfo.environment) {
            observer.setTimeOffset(hours: hours)
            refreshField()
        }
        if LaunchMode.asterismsEnabled(environment: ProcessInfo.processInfo.environment) {
            showsAsterisms = true
            scene.setAsterismsVisible(true)
        }
        if LaunchMode.outlinesEnabled(environment: ProcessInfo.processInfo.environment) {
            showsOutlines = true
            scene.setSilhouettesVisible(true)
        }
        if LaunchMode.allLayersEnabled(environment: ProcessInfo.processInfo.environment) {
            showsConstellations = true
            showsOutlines = true
            showsAsterisms = true
            showsPatterns = true
            scene.setConstellationsVisible(true)
            scene.setSilhouettesVisible(true)
            scene.setAsterismsVisible(true)
            scene.setPatternsVisible(true)
        }
        if let raw = LaunchMode.patternPreview(environment: ProcessInfo.processInfo.environment) {
            showsPatterns = true
            scene.setPatternsVisible(true)
            let id = raw == "1" ? SkyPatternCatalog.all.first?.id : raw
            if let id {
                for _ in 0..<60 where scene.direction(forPattern: id) == nil {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                if let direction = scene.direction(forPattern: id) {
                    scene.aim(at: direction)
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
            Task {
                while !Task.isCancelled {
                    stepDwell()
                    try? await Task.sleep(for: .milliseconds(80))
                }
            }
        }
        if let abbreviation = LaunchMode.regionPreview(environment: ProcessInfo.processInfo.environment),
           let region = ConstellationInfo.region(for: abbreviation, in: catalog?.stars ?? []) {
            currentRegion = .constellation(region)
            try? await Task.sleep(for: .seconds(2))
            infoRegion = region
        }
        if let title = LaunchMode.groupPreview(environment: ProcessInfo.processInfo.environment),
           let stars = catalog?.stars {
            let groups = SkyGroupIndex.groups(stars: stars)
            if let group = groups.first(where: { $0.title == title })
                ?? SkyGroupIndex.search(groups, query: title).first {
                try? await Task.sleep(for: .milliseconds(600))
                focus(group: group)
            }
        }
        if let abbreviation = LaunchMode.aimTarget(environment: ProcessInfo.processInfo.environment),
           let stars = catalog?.stars {
            let members = stars.filter { $0.constellation == abbreviation }
            if !members.isEmpty {
                var sum = SIMD3<Float>(0, 0, 0)
                for star in members {
                    sum += SkyPicker.direction(for: star)
                }
                for _ in 0..<40 where !scene.isReady {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                scene.aim(at: sum)
                SessionLog.append("sky.aim target=\(abbreviation) stars=\(members.count)")
            }
        }
        if let name = LaunchMode.starPreview(environment: ProcessInfo.processInfo.environment),
           let star = catalog?.stars.first(where: { $0.name == name }) {
            selected = star
        }
        if let target = LaunchMode.guideTarget(environment: ProcessInfo.processInfo.environment) {
            let stars = catalog?.stars ?? []
            if let star = stars.first(where: { $0.name == target }) {
                startGuide(to: star)
            }
        }
        if LaunchMode.perfLogEnabled(environment: ProcessInfo.processInfo.environment) {
            let showsHUD = LaunchMode.fpsHUDEnabled(environment: ProcessInfo.processInfo.environment)
            Task {
                var loggedBudget = false
                while !Task.isCancelled {
                    if !loggedBudget, scene.isReady {
                        loggedBudget = true
                        SessionLog.append(scene.budget())
                    }
                    let summary = perf.tick(
                        now: ProcessInfo.processInfo.systemUptime,
                        layers: layerLabel
                    )
                    if showsHUD { perfSummary = summary }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    /// 当前点亮了哪几层，写进 `sky.perf`，掉帧时能对上号。
    private var layerLabel: String {
        var parts: [String] = []
        if showsConstellations { parts.append("line") }
        if showsOutlines { parts.append("outline") }
        if showsAsterisms { parts.append("asterism") }
        if showsPatterns { parts.append("pattern") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }

    private func startMotion() {
        guard LaunchMode.skyMotionEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        guard !attitude.isAvailable else { return }
        attitude.start { orientation in
            scene.setAttitude(orientation)
            if observer.calibrate(sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField)) {
                refreshField()
            }
            stepDwell()
        }
        motionActive = attitude.isAvailable
    }

    private func toggleAlignment() {
        if observer.isOn {
            observer.disable()
            SessionLog.append("sky.align off")
        } else {
            observer.enable()
        }
        refreshField()
        refreshTonight()
    }

    private func refreshField() {
        guard let orientation = observer.fieldOrientation() else {
            scene.setField(orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
            return
        }
        scene.setField(orientation: orientation)
    }

    private func horizontal(for star: Star) -> Astronomy.Horizontal? {
        guard observer.stage == .ready,
              let latitude = observer.latitude,
              let sidereal = observer.currentSiderealDegrees()
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

    /// 点环落在某星座轮廓内时开始计时，满 0.6 秒确认并弹标识卡。
    /// 返回 nil 表示当前不在任何星座轮廓内。
    private func constellationProgress(at now: TimeInterval) -> Double? {
        guard let constellation = scene.constellationAtCenter() else {
            resetConstellationTracking()
            return nil
        }
        if constellationHold.key != constellation.abbreviation {
            constellationHold = ConstellationHold(key: constellation.abbreviation, since: now)
            scene.highlightConstellation(constellation.abbreviation)
            identifiedConstellation = nil
        }
        let held = now - constellationHold.since
        let progress = min(max(held / ConstellationHold.required, 0), 1)
        if progress >= 1,
           identifiedConstellation?.abbreviation != constellation.abbreviation,
           constellationDismissed != constellation.abbreviation {
            identifiedConstellation = constellation
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            SessionLog.append("sky.constellation dwell=\(constellation.abbreviation)")
        }
        return progress
    }

    private func resetConstellationTracking() {
        guard constellationHold.key != nil || identifiedConstellation != nil else { return }
        constellationHold = ConstellationHold()
        identifiedConstellation = nil
        constellationDismissed = nil
        scene.highlightConstellation(nil)
    }

    /// 点环落在闭合星群内部时开始计时。星群比星座大得多，0.6 秒的停留门槛
    /// 是为了挡掉「扫过去」而不是「看着它」的情况。
    private func patternProgress(at now: TimeInterval) -> Double? {
        guard let pattern = scene.patternAtCenter() else {
            resetPatternTracking()
            return nil
        }
        if patternHold.key != pattern.id {
            patternHold = ConstellationHold(key: pattern.id, since: now)
            scene.highlightPattern(pattern.id)
            identifiedPattern = nil
        }
        let held = now - patternHold.since
        let progress = min(max(held / ConstellationHold.required, 0), 1)
        if progress >= 1,
           identifiedPattern?.id != pattern.id,
           patternDismissed != pattern.id {
            identifiedPattern = pattern
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            SessionLog.append("sky.pattern dwell=\(pattern.id)")
        }
        return progress
    }

    private func resetPatternTracking() {
        guard patternHold.key != nil || identifiedPattern != nil else { return }
        patternHold = ConstellationHold()
        identifiedPattern = nil
        patternDismissed = nil
        scene.highlightPattern(nil)
    }

    private func stepDwell() {
        guard scene.isReady else { return }
        let frameNow = ProcessInfo.processInfo.systemUptime
        if frameNow - regionStamp > 0.5 {
            regionStamp = frameNow
            let region = scene.currentRegion()
            if region?.key != currentRegion?.key {
                SessionLog.append(
                    String(
                        format: "sky.region name=%@ distance=%.1f",
                        region?.key ?? "none",
                        region?.distance ?? -1
                    )
                )
            }
            currentRegion = region
        }
        if let target = guide {
            let vector = scene.guideVector(to: target)
            guideVector = vector
            guard let vector, vector.isAligned else { return }
            selected = target
            guide = nil
            guideVector = nil
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            SessionLog.append("sky.guide arrived=\(target.name)")
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let candidate = scene.pickAtCenter()
        if candidate == nil, now - diagnosticsStamp > 1.5,
           LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) {
            diagnosticsStamp = now
            SessionLog.append(scene.pickDiagnostics())
        }
        let hit = dwell.update(candidate: candidate, at: now)
        if candidate == nil {
            // 优先级：星体 > 星座轮廓 > 星群。指着猎户座就说猎户座，
            // 只有落在没有轮廓的天区里，星群才有资格说话。
            if let progress = constellationProgress(at: now) {
                resetPatternTracking()
                hud.show(progress)
                return
            }
            if let progress = patternProgress(at: now) {
                hud.show(progress)
                return
            }
        } else {
            resetConstellationTracking()
            resetPatternTracking()
        }
        hud.show(dwell.progress)
        guard let hit else { return }
        selected = hit
        selectedGroup = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SessionLog.append(
            String(
                format: "sky.dwell name=%@ mag=%.2f offset=%.1f",
                hit.name,
                hit.magnitude,
                scene.aimOffsetDegrees(of: hit)
            )
        )
    }

    private func runPickProbe() async {
        guard LaunchMode.pickProbeEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        for _ in 0..<60 {
            let alignmentSettled = !observer.isOn
                || observer.stage == .ready
                || observer.stage == .denied
                || observer.stage == .unavailable
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

private struct DwellRing: View {
    var hud: DwellHUD

    var body: some View {
        Circle()
            .trim(from: 0, to: hud.progress)
            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 41, height: 41)
            .opacity(hud.progress > 0.01 ? 0.95 : 0)
    }
}

struct AsterismFocus: Identifiable, Equatable {
    var id: String
}

struct ConstellationHold {
    static let required: TimeInterval = 0.6
    var key: String?
    var since: TimeInterval = 0
}
