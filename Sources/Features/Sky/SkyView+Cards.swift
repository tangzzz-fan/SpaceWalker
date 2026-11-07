import RealityKit
import SwiftUI
import TGReduxKit
import UIKit

extension SkyView {
    // MARK: - 卡片

    @ViewBuilder
    var activeCards: some View {
        if let guide = session.guide {
            guideBar(guide)
        }
        if let constellation = session.identifiedConstellation {
            constellationBadge(constellation)
        }
        if let asterism = session.identifiedAsterism {
            asterismCard(asterism)
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

    func guideBar(_ star: Star) -> some View {
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

    func startGuide(to star: Star) {
        session.guide = star
        session.guideVector = scene.guideVector(to: star)
        session.selected = nil
        session.selectedGroup = nil
        session.attention.resetStar()
        hud.show(0)
        SessionLog.append("sky.guide start=\(star.name)")
    }

    func refreshTonight() {
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

    func focus(group: SkyGroup) {
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

    func constellationBadge(_ constellation: Constellation) -> some View {
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

    func asterismCard(_ asterism: Asterism) -> some View {
        let lords = FengshenInfo.lords(forAsterism: asterism.name)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "circle.grid.3x3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(asterism.name)
                    .font(.headline)
                Text(asterism.isMansion ? "二十八宿" : "星官")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
            }
            Text("\(asterism.members.count) 颗成员星 · \(asterism.segmentCount) 段连线")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let lord = lords.first {
                Text("封神：\(lord.title) · \(lord.person)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("落在星官内 0.6 秒识别")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .padding(.trailing, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Button {
                session.attention.dismiss(.asterism(asterism.name))
                session.identifiedAsterism = nil
                scene.highlightAsterism(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .padding(8)
            }
            .accessibilityLabel("收起星官卡")
        }
    }

    func patternBadge(_ pattern: SkyPattern) -> some View {
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

    func groupCard(_ group: SkyGroup) -> some View {
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

    func starCard(_ star: Star) -> some View {
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

    func alignmentButton(star: Star, azimuth: Double) -> some View {
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

    func aimOffset(for star: Star) -> Double {
        scene.aimOffsetDegrees(of: star)
    }

    func calibrateFacingNorth() {
        session.observer.calibrateAgainst(
            starAzimuth: 0,
            sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField),
            label: "正北"
        )
        refreshField()
    }

    func calibrate(using star: Star, azimuth: Double) {
        session.observer.calibrateAgainst(
            starAzimuth: azimuth,
            sceneAzimuth: Astronomy.sceneAzimuth(scene.viewDirectionInField),
            label: star.name
        )
        refreshField()
    }

    var creditsSheet: some View {
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
}
