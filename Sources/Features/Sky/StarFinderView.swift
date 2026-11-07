import SwiftUI

struct StarFinderView: View {
    var stars: [Star]
    var initialQuery: String = ""
    var tonight: [TonightPick] = []
    var referenceDate: Date = Date()
    var onPick: (Star) -> Void
    var onPickGroup: (SkyGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var constellation: StarFinder.ConstellationGroup?
    @State private var showsAllChinese = false
    @State private var tour: TonightTour?
    @State private var showsFengshen = false
    private let startsWithTour: Bool
    private let fengshenTarget: String?

    init(
        stars: [Star],
        initialQuery: String = "",
        tonight: [TonightPick] = [],
        referenceDate: Date = Date(),
        initialTour: Bool = false,
        initialFengshen: String? = nil,
        onPick: @escaping (Star) -> Void,
        onPickGroup: @escaping (SkyGroup) -> Void
    ) {
        self.stars = stars
        self.initialQuery = initialQuery
        self.tonight = tonight
        self.referenceDate = referenceDate
        self.onPick = onPick
        self.onPickGroup = onPickGroup
        _query = State(initialValue: initialQuery)
        startsWithTour = initialTour
        fengshenTarget = initialFengshen
    }

    private var results: [StarFinder.Hit] {
        StarFinder.search(stars, query: query)
    }

    private var allGroups: [SkyGroup] {
        SkyGroupIndex.groups(stars: stars)
    }

    private var groupResults: [SkyGroup] {
        SkyGroupIndex.search(allGroups, query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchSection
                } else if let constellation {
                    constellationSection(constellation)
                } else {
                    tonightSection
                    groupSection
                    chineseSection
                    curatedSection
                    brightestSection
                    constellationGrid
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(constellation?.name ?? "找一颗星")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if constellation != nil {
                        Button("返回") { self.constellation = nil }
                    } else {
                        Button("关闭") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsFengshen = true
                    } label: {
                        Label("封神星榜", systemImage: "scroll")
                    }
                    .accessibilityLabel("封神星榜")
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "星名 / 中文名 / 星座")
        }
        .task {
            if fengshenTarget != nil, !showsFengshen {
                showsFengshen = true
            }
            guard startsWithTour, tour == nil else { return }
            tour = TonightTour.build(picks: tonight, date: referenceDate)
        }
        .sheet(item: $tour) { tour in
            TonightTourView(tour: tour) { group in
                self.tour = nil
                onPickGroup(group)
                dismiss()
            }
        }
        .sheet(isPresented: $showsFengshen) {
            FengshenBoardView(
                initialDepartment: initialFengshenDepartment,
                initialQuery: initialFengshenQuery
            ) { asterism in
                showsFengshen = false
                locate(asterism: asterism)
            }
        }
    }

    private var searchSection: some View {
        Group {
            if !groupResults.isEmpty {
                Section("星官 / 星座 / 宿") {
                    ForEach(groupResults) { group in
                        groupRow(group)
                    }
                }
            }
            if results.isEmpty, groupResults.isEmpty {
                Section {
                    Text("没有匹配，试试「天狼」「参宿」「北斗」「参水猿」")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if !results.isEmpty {
                Section {
                    ForEach(results, id: \.star.name) { hit in
                        row(hit)
                    }
                } header: {
                    Text("恒星 \(results.count)")
                }
            }
        }
    }

    private var tonightSection: some View {
        Group {
            if !tonight.isEmpty {
                Section {
                    ForEach(tonight) { pick in
                        Button {
                            onPickGroup(pick.group)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(pick.group.title)
                                            .font(.body)
                                        if pick.isWellPlaced {
                                            Text("位置好")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1)
                                                .background(.green.opacity(0.22), in: Capsule())
                                        }
                                    }
                                    Text("\(pick.altitudeText) · 最佳 \(pick.seasonText)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "scope")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("今夜此刻最适合看")
                        Spacer()
                        Button("开始导览") {
                            tour = TonightTour.build(picks: tonight, date: referenceDate)
                        }
                        .font(.caption.weight(.medium))
                        .textCase(nil)
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                } footer: {
                    Text("按当前高度与该星座最亮星综合排序，只列高度 12° 以上的星座。")
                }
            }
        }
    }

    private var groupSection: some View {
        Section {
            ForEach(Array(allGroups.prefix(12))) { group in
                groupRow(group)
            }
        } header: {
            Text("星官与星宿")
        } footer: {
            Text("星官是中国传统的星组划分，与西方星座边界不重合。搜索星宿名或封神名号（如「参水猿」）也能直接定位。")
        }
    }

    private func groupRow(_ group: SkyGroup) -> some View {
        Button {
            onPickGroup(group)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.title)
                            .font(.body)
                        Text(group.kind.label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.tint.opacity(0.18), in: Capsule())
                    }
                    HStack(spacing: 6) {
                        Text(group.subtitle)
                        if let line = group.fengshenLine {
                            Text(line)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func constellationSection(_ group: StarFinder.ConstellationGroup) -> some View {
        Group {
            if let fact = ConstellationInfo.fact(for: group.abbreviation) {
                Section("来头") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(fact.westernLore)
                            .font(.callout)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(fact.chineseLore)
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
            Section {
                ForEach(group.stars.prefix(40), id: \.name) { star in
                    row(StarFinder.hit(for: star))
                }
            } header: {
                Text("\(group.name) · \(group.stars.count) 颗可选中")
            }
        }
    }

    private var chineseSection: some View {
        let all = StarFinder.chineseNamed(stars)
        let shown = showsAllChinese ? all : Array(all.prefix(10))
        return Section {
            ForEach(shown, id: \.star.name) { hit in
                row(hit)
            }
            if all.count > shown.count {
                Button("查看全部 \(all.count) 颗中文星名") {
                    showsAllChinese = true
                }
                .font(.callout)
            }
        } header: {
            Text("中文星名")
        } footer: {
            Text("星官名来自中国传统星表；其中天关、玄戈、天一、傅说为国际天文学联合会（IAU）2017 年正式采用的名称。")
        }
    }

    private var curatedSection: some View {
        let groups = StarFinder.groups(stars)
        return Group {
            if !groups.isEmpty {
                Section("经典组合") {
                    ForEach(groups, id: \.0) { title, hits in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(hits, id: \.star.name) { hit in
                                        Button {
                                            pick(hit.star)
                                        } label: {
                                            Text(hit.chinese ?? hit.star.name)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(.quaternary, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var brightestSection: some View {
        Section("最亮 20 颗") {
            ForEach(StarFinder.brightest(stars), id: \.star.name) { hit in
                row(hit)
            }
        }
    }

    private var constellationGrid: some View {
        let groups = StarFinder.constellations(stars)
        return Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(groups, id: \.abbreviation) { group in
                    Button {
                        constellation = group
                    } label: {
                        VStack(spacing: 2) {
                            Text(group.name)
                                .font(.caption)
                            Text("\(group.stars.count) 颗")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("按星座（\(groups.count) 个）")
        }
    }

    private func row(_ hit: StarFinder.Hit) -> some View {
        Button {
            pick(hit.star)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(hit.chinese ?? hit.star.name)
                            .font(.body)
                        if hit.chinese != nil {
                            Text(hit.star.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if hit.official {
                            Text("IAU")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.tint.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(String(format: "%@ · 视星等 %.1f", ConstellationNames.chinese(for: hit.star.constellation) ?? hit.star.constellation, hit.star.magnitude))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "location.north.line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func pick(_ star: Star) {
        onPick(star)
        dismiss()
    }

    private var initialFengshenDepartment: String? {
        guard let fengshenTarget, FengshenInfo.departments.contains(fengshenTarget) else { return nil }
        return fengshenTarget
    }

    private var initialFengshenQuery: String {
        guard let fengshenTarget, fengshenTarget != "1", initialFengshenDepartment == nil else { return "" }
        return fengshenTarget
    }

    private func locate(asterism: String) {
        let groups = SkyGroupIndex.groups(stars: stars)
        guard let group = SkyGroupIndex.group(forAsterism: asterism, in: groups) else { return }
        onPickGroup(group)
        dismiss()
    }
}
