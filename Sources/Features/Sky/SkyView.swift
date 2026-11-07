import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

struct SkyView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Bindable var session: SkySession

    private var scene: SkyScene { session.scene }
    @State private var showsCredits = false
    @State private var fengshenFocus: AsterismFocus?
    @State private var showsFinder = false
    @State private var hud = DwellHUD()
    @State private var perfSummary: ProbeSummary?
    @State private var diagnosticsStamp: TimeInterval = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if session.catalog != nil {
                GeometryReader { proxy in
                    reality
                        .onAppear {
                            session.resize(proxy.size)
                            logLayout(proxy.size)
                        }
                        .onChange(of: proxy.size) { _, size in
                            session.resize(size)
                            logLayout(size)
                        }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            crosshair

            if isLandscape {
                landscapeOverlay
            } else {
                portraitOverlay
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
            await runPickProbe()
        }
        .onChange(of: session.showsConstellations) { _, visible in
            scene.setConstellationsVisible(visible)
        }
        .onChange(of: session.showsAsterisms) { _, visible in
            scene.setAsterismsVisible(visible)
        }
        .onChange(of: session.showsOutlines) { _, visible in
            scene.setSilhouettesVisible(visible)
        }
        .onChange(of: session.showsPatterns) { _, visible in
            scene.setPatternsVisible(visible)
            if !visible {
                session.identifiedPattern = nil
            }
        }
        .onChange(of: session.selectedGroup) { _, group in
            scene.highlightAsterism(group?.asterismID)
        }
        .onChange(of: session.observer.stage) { _, _ in
            refreshField()
            refreshTonight()
        }
        .onDisappear {
            session.stopMotion()
            session.observer.disable()
        }
        .sheet(isPresented: $showsCredits) { creditsSheet }
        .sheet(item: $session.infoRegion) { region in
            ConstellationInfoView(region: region, stars: session.catalog?.stars ?? []) { star in
                startGuide(to: star)
            }
        }
        .sheet(item: $fengshenFocus) { target in
            FengshenBoardView(focusAsterism: target.id) { asterism in
                fengshenFocus = nil
                if let group = SkyGroupIndex.group(forAsterism: asterism, in: session.groups) {
                    focus(group: group)
                }
            }
        }
        .sheet(isPresented: $showsFinder) {
            StarFinderView(
                stars: session.catalog?.stars ?? [],
                initialQuery: LaunchMode.finderQuery(environment: ProcessInfo.processInfo.environment),
                tonight: session.tonight,
                referenceDate: session.observer.shiftedNow(),
                initialTour: LaunchMode.tourPreviewEnabled(environment: ProcessInfo.processInfo.environment),
                initialFengshen: LaunchMode.fengshenTarget(environment: ProcessInfo.processInfo.environment),
                onPick: { star in startGuide(to: star) },
                onPickGroup: { group in focus(group: group) }
            )
        }
    }

    private var reality: some View {
        RealityView { content in
            content.environment = .default
            guard let catalog = session.catalog else { return }
            scene.build(catalog: catalog)
            content.add(scene.root)
            scene.attach(content)
            if LaunchMode.perfLogEnabled(environment: ProcessInfo.processInfo.environment) {
                session.perf.attach(content)
            }
            session.applyRig()
        } update: { _ in
            session.applyRig()
        }
        .coordinateSpace(name: SkyScene.coordinateSpaceName)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    session.drag(to: value.translation)
                }
                .onEnded { _ in
                    session.endDrag()
                }
        )
        // 双指捏合改视场角。人放在星空上叫「看全」，不是在缩放图片：
        // 人马座 35° 装不进 36° 的竖屏视场，只能连视场一起放大。
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    session.magnify(value.magnification)
                }
                .onEnded { _ in
                    session.endMagnify()
                }
        )
        // 双击回到默认视场。缩放没有「复位」就等于没有退出键，
        // 放到 95° 之后很难再捏回 60°。
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                session.resetZoom()
            }
        )
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .named(SkyScene.coordinateSpaceName))
                .onEnded { value in
                    let hit = scene.pick(at: value.location)
                    session.selected = hit
                    session.selectedGroup = nil
                    session.attention.resetStar()
                    hud.show(0)
                    SessionLog.append("sky.select name=\(hit?.name ?? "none") mag=\(hit?.magnitude ?? 0)")
                }
        )
    }

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    /// 竖屏：顶栏在上，卡片与底栏依次叠在下方。
    private var portraitOverlay: some View {
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
    private var landscapeOverlay: some View {
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
    private var activeCards: some View {
        if let guide = session.guide {
            guideBar(guide)
        }
        if let constellation = session.identifiedConstellation {
            constellationBadge(constellation)
        }
        if let pattern = session.identifiedPattern {
            patternBadge(pattern)
        }
        if let selectedGroup = session.selectedGroup {
            groupCard(selectedGroup)
        }
        if let selected = session.selected {
            starCard(selected)
        }
    }

    @ViewBuilder
    private func perfBadge(alignment: Alignment) -> some View {
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
    private var compactTopBar: some View {
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

    private var compactSubtitle: String {
        if !session.isMotionActive {
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

    private func openRegion(_ region: SkyRegion) {
        switch region {
        case .constellation(let info):
            session.infoRegion = info
        case .pattern(let pattern):
            session.identifiedPattern = pattern
        }
    }

    /// 转屏时留一行尺寸，排查排版时不用猜当时是哪个方向。
    private func logLayout(_ size: CGSize) {
        SessionLog.append(
            String(format: "sky.layout %.0fx%.0f %@", size.width, size.height, isLandscape ? "landscape" : "portrait")
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
            Text(session.isMotionActive ? "姿态跟随 · 转动手机环顾" : "拖动旋转（无陀螺仪时的降级）")
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

    private func regionSymbol(_ region: SkyRegion) -> String {
        switch region {
        case .constellation: "book.closed"
        case .pattern: "triangle"
        }
    }

    private var skySubtitle: String {
        guard session.observer.stage == .ready,
              let latitude = session.observer.latitude,
              let longitude = session.observer.longitude,
              let sidereal = session.observer.currentSiderealDegrees()
        else {
            let stars = session.catalog?.stars ?? []
            return "\(stars.count) 颗恒星 · \(stars.filter(\.isSelectable).count) 颗可选中 · \(Constellations.all.count) 个星座 · \(AsterismCatalog.all.count) 个星官"
        }
        let base = String(format: "%.1f°N %.1f°E · 恒星时 %.1f°", latitude, longitude, sidereal)
        return session.observer.clock.isNow ? base : "\(base) · \(timeOffsetLabel)"
    }

    private var timeScrubber: some View {
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

    private var timeOffsetBinding: Binding<Double> {
        Binding(
            get: { session.observer.timeOffsetHours },
            set: { hours in
                session.observer.setTimeOffset(hours: hours)
                refreshField()
                refreshTonight()
            }
        )
    }

    private var timeOffsetLabel: String {
        let hours = session.observer.timeOffsetHours
        if session.observer.clock.isNow {
            return "此刻"
        }
        let minutes = Int((hours * 60).rounded())
        let sign = minutes < 0 ? "-" : "+"
        let magnitude = abs(minutes)
        return String(format: "%@%d:%02d", sign, magnitude / 60, magnitude % 60)
    }

    private var hintBar: some View {
        HStack(spacing: 8) {
            if !session.isMotionActive {
                Button {
                    session.resetOrientation()
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
                Toggle(isOn: $session.showsConstellations) {
                    Label("星座连线", systemImage: "link")
                }
                Toggle(isOn: $session.showsOutlines) {
                    Label("星座轮廓", systemImage: "square.on.circle")
                }
                Divider()
                Toggle(isOn: $session.showsPatterns) {
                    Label("星群（大三角）", systemImage: "triangle")
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

            Button {
                session.showsAsterisms.toggle()
            } label: {
                Label("星官", systemImage: "circle.grid.3x3")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(session.showsAsterisms ? Color(red: 0.94, green: 0.82, blue: 0.56) : .primary)
            }
            .accessibilityLabel("中国星官连线")

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

    private func guideBar(_ star: Star) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.fill")
                .font(.title3)
                .rotationEffect(.degrees(session.guideVector?.arrowDegrees ?? 0))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("前往 \(ChineseStarNames.chinese(for: star.name) ?? star.name)")
                    .font(.subheadline.weight(.medium))
                Text(session.guideVector?.instruction ?? "转动手机寻找…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                session.guide = nil
                session.guideVector = nil
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
        session.guide = star
        session.guideVector = scene.guideVector(to: star)
        session.selected = nil
        session.selectedGroup = nil
        session.attention.resetStar()
        hud.show(0)
        SessionLog.append("sky.guide start=\(star.name)")
    }

    private func refreshTonight() {
        guard session.observer.stage == .ready,
              let latitude = session.observer.latitude,
              let longitude = session.observer.longitude,
              !session.groups.isEmpty
        else {
            session.tonight = []
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - session.tonightStamp > 0.4 else { return }
        session.tonightStamp = now
        session.tonight = SkySeason.rank(
            groups: session.groups,
            stars: session.catalog?.stars ?? [],
            latitude: latitude,
            longitude: longitude
        )
    }

    private func focus(group: SkyGroup) {
        let stars = session.catalog?.stars ?? []
        guard let direction = SkyGroupIndex.anchor(group, stars: stars) else { return }
        session.aim(at: direction)
        if group.isDrawable, !session.showsAsterisms {
            session.showsAsterisms = true
            scene.setAsterismsVisible(true)
        }
        session.selectedGroup = group
        session.selected = nil
        session.guide = nil
        session.guideVector = nil
        session.attention.resetStar()
        hud.show(0)
        SessionLog.append("sky.group focus=\(group.id) members=\(group.memberCount)")
    }

    private func constellationBadge(_ constellation: Constellation) -> some View {
        let latin = ConstellationInfo.latinNames[constellation.abbreviation] ?? constellation.abbreviation
        return HStack(alignment: .top, spacing: 12) {
            ConstellationArtView(abbreviation: constellation.abbreviation, size: 96)
            VStack(alignment: .leading, spacing: 5) {
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
                        session.infoRegion = ConstellationInfo.region(
                            for: constellation.abbreviation,
                            in: session.catalog?.stars ?? []
                        )
                    } label: {
                        Image(systemName: "book.closed")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看星座来头")
                }
                // 识别卡只回答两件事：这是谁、凭什么。神话留给「查看来头」，
                // 挤在这里会把「怎么认」压成两行省略号。
                if let note = ConstellationShapeNote.note(for: constellation.abbreviation) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(constellation.starCount) 颗连线星 · 落在骨架范围内 0.6 秒识别")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .padding(.trailing, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                session.identifiedConstellation = nil
                session.attention.dismiss(.constellation(constellation.abbreviation))
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
                session.identifiedPattern = nil
                session.attention.dismiss(.pattern(pattern.id))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func groupCard(_ group: SkyGroup) -> some View {
        let stars = session.catalog?.stars ?? []
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
                if let latitude = session.observer.latitude, let sidereal = session.observer.currentSiderealDegrees() {
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
                        session.selected = member
                        session.selectedGroup = nil
                        session.attention.resetStar()
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
                session.selectedGroup = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private func starCard(_ star: Star) -> some View {
        let display = StarDisplay.make(for: star)
        let nearby = SkyPicker.nearby(to: star, in: session.catalog?.stars ?? [])
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
                            session.selected = item
                            session.attention.resetStar()
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
                session.selected = nil
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
        session.observer.calibrateAgainst(
            starAzimuth: 0,
            sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField),
            label: "正北"
        )
        refreshField()
    }

    private func calibrate(using star: Star, azimuth: Double) {
        session.observer.calibrateAgainst(
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
            session.showsAsterisms = true
            session.showsPatterns = true
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
            Task {
                while !Task.isCancelled {
                    stepDwell()
                    try? await Task.sleep(for: .milliseconds(80))
                }
            }
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
            Task {
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
            }
        }
    }

    /// 当前点亮了哪几层，写进 `sky.perf`，掉帧时能对上号。
    private var layerLabel: String {
        var parts: [String] = []
        if session.showsConstellations { parts.append("line") }
        if session.showsOutlines { parts.append("outline") }
        if session.showsAsterisms { parts.append("asterism") }
        if session.showsPatterns { parts.append("pattern") }
        return parts.isEmpty ? "none" : parts.joined(separator: "+")
    }

    private func startMotion() {
        guard LaunchMode.skyMotionEnabled(environment: ProcessInfo.processInfo.environment) else { return }
        session.startMotion {
            if session.observer.calibrate(sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField)) {
                refreshField()
            }
            stepDwell()
        }
    }

    private func toggleAlignment() {
        if session.observer.isOn {
            session.observer.disable()
            SessionLog.append("sky.align off")
        } else {
            session.observer.enable()
        }
        refreshField()
        refreshTonight()
    }

    private func refreshField() {
        guard let orientation = session.observer.fieldOrientation() else {
            scene.setField(orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
            return
        }
        scene.setField(orientation: orientation)
    }

    private func horizontal(for star: Star) -> Astronomy.Horizontal? {
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

    private func stepDwell() {
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
                pattern: session.showsPatterns ? candidates.pattern?.id : nil
            )
        )
        react(to: step, candidates: candidates)
        hud.show(step.progress)
    }

    private func react(to step: AttentionArbiter.Step, candidates: SkyScene.Candidates) {
        for effect in step.effects {
            switch effect {
            case .highlight(let target):
                switch target {
                case .constellation(let key):
                    scene.highlightConstellation(key)
                case .pattern(let id):
                    scene.highlightPattern(id)
                case .star, .none:
                    scene.highlightConstellation(nil)
                    scene.highlightPattern(nil)
                    session.identifiedConstellation = nil
                    session.identifiedPattern = nil
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
                case .pattern(let id):
                    session.selected = nil
                    session.identifiedPattern = candidates.pattern
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    SessionLog.append("sky.pattern dwell=\(id)")
                }
            }
        }
    }

    private func runPickProbe() async {
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
