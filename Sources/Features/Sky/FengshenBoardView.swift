import SwiftUI

/// 封神星榜：按部浏览《封神演义》第九十九回的三百六十五位正神，
/// 其中有星官对应者可一键定位到星图。
struct FengshenBoardView: View {
    var onLocate: (String) -> Void
    /// 水浒对照属深度层，未释出时整块不出现。
    var showsShuihu = true

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var path: [String]
    @State private var highlight: Set<String>
    @State private var onlyLocatable = false

    init(
        focusAsterism: String? = nil,
        initialDepartment: String? = nil,
        initialQuery: String = "",
        showsShuihu: Bool = true,
        onLocate: @escaping (String) -> Void
    ) {
        self.onLocate = onLocate
        self.showsShuihu = showsShuihu
        _query = State(initialValue: initialQuery)
        _path = State(initialValue: Self.initialPath(
            focusAsterism: focusAsterism,
            department: initialDepartment
        ))
        _highlight = State(initialValue: Set(
            focusAsterism.map { asterism in
                FengshenInfo.lords(forAsterism: asterism).map(\.id)
            } ?? []
        ))
    }

    static let shuihuRoute = "@shuihu"

    private static func initialPath(focusAsterism: String?, department: String?) -> [String] {
        if let department {
            return [department]
        }
        guard let focusAsterism,
              let first = FengshenInfo.lords(forAsterism: focusAsterism).first
        else { return [] }
        return [first.department]
    }

    private var locatableCount: Int {
        FengshenInfo.all.filter(\.isLocatable).count
    }

    private var base: [FengshenLord] {
        onlyLocatable ? FengshenInfo.all.filter(\.isLocatable) : FengshenInfo.all
    }

    private var matches: [FengshenLord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return base.filter { lord in
            lord.title.contains(trimmed)
                || lord.person.contains(trimmed)
                || lord.department.contains(trimmed)
                || lord.group.contains(trimmed)
                || (lord.asterism?.contains(trimmed) ?? false)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Picker("范围", selection: $onlyLocatable) {
                        Text("全部 \(FengshenInfo.all.count)").tag(false)
                        Text("可定位 \(locatableCount)").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if showsShuihu, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        NavigationLink(value: Self.shuihuRoute) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("一百单八将")
                                        .font(.body)
                                    Text("天罡地煞与梁山座次逐位对照")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 6)
                                Text("\(FengshenInfo.shuihuRoster.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    directory
                } else if matches.isEmpty {
                    Section {
                        Text("没有匹配，试试「角木蛟」「闻仲」「天魁」「斗部」")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("命中 \(matches.count) 位") {
                        ForEach(matches) { lord in
                            FengshenRow(
                                lord: lord,
                                showsAffiliation: true,
                                highlighted: highlight.contains(lord.id),
                                showsShuihu: showsShuihu,
                                onLocate: onLocate
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("封神星榜")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "名号 / 人物 / 部"
            )
            .navigationDestination(for: String.self) { destination in
                if destination == Self.shuihuRoute {
                    ShuihuRosterView()
                } else {
                    FengshenDepartmentView(
                        department: destination,
                        onlyLocatable: onlyLocatable,
                        highlight: highlight,
                        showsShuihu: showsShuihu,
                        onLocate: onLocate
                    )
                }
            }
        }
    }

    private var directory: some View {
        Section {
            ForEach(FengshenInfo.departments, id: \.self) { department in
                let count = base.filter { $0.department == department }.count
                if count > 0 {
                    NavigationLink(value: department) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(department)
                                    .font(.body)
                                if let note = FengshenInfo.departmentNotes[department] {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 6)
                            Text("\(count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        } header: {
            Text("八部正神")
        } footer: {
            Text(FengshenInfo.sourceNote)
        }
    }
}

struct FengshenDepartmentView: View {
    var department: String
    var onlyLocatable: Bool
    var highlight: Set<String> = []
    var showsShuihu = true
    var onLocate: (String) -> Void

    private var lords: [FengshenLord] {
        let all = FengshenInfo.lords(in: department)
        return onlyLocatable ? all.filter(\.isLocatable) : all
    }

    private var groups: [String] {
        var seen = Set<String>()
        return lords.compactMap { seen.insert($0.group).inserted ? $0.group : nil }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if let note = FengshenInfo.departmentNotes[department] {
                    Section {
                        Text(note)
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(groups, id: \.self) { group in
                    let members = lords.filter { $0.group == group }
                    Section("\(group) · \(members.count) 位") {
                        ForEach(members) { lord in
                            FengshenRow(
                                lord: lord,
                                showsAffiliation: false,
                                highlighted: highlight.contains(lord.id),
                                showsShuihu: showsShuihu,
                                onLocate: onLocate
                            )
                            .id(lord.id)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(department)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let first = highlight.first else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation { proxy.scrollTo(first, anchor: .center) }
                }
            }
        }
    }
}

private struct FengshenRow: View {
    var lord: FengshenLord
    var showsAffiliation: Bool
    var highlighted: Bool = false
    var showsShuihu = true
    var onLocate: (String) -> Void

    var body: some View {
        if let asterism = lord.asterism {
            Button {
                onLocate(asterism)
            } label: {
                content(asterism: asterism)
            }
            .buttonStyle(.plain)
        } else {
            content(asterism: nil)
        }
    }

    private func content(asterism: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(lord.title)
                        .font(.body)
                    Text(lord.person)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if showsAffiliation {
                        Text(lord.affiliation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let alsoServes = lord.alsoServes {
                        Text("兼\(alsoServes)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                    if let note = lord.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                if showsShuihu, let shuihu = lord.shuihu {
                    HStack(spacing: 5) {
                        Text("水浒")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.22), in: Capsule())
                        Text("\(shuihu.rank) · \(shuihu.nickname) \(shuihu.person)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 6)
            if let asterism {
                Text(asterism)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.16), in: Capsule())
                Image(systemName: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, highlighted ? 6 : 0)
        .background(
            highlighted ? Color.accentColor.opacity(0.14) : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }
}

/// 一百单八将：梁山座次 ↔ 封神榜星君逐位对照。
struct ShuihuRosterView: View {
    private var tiangang: [FengshenLord] {
        FengshenInfo.shuihuRoster.filter { $0.group == "天罡三十六" }
    }

    private var disha: [FengshenLord] {
        FengshenInfo.shuihuRoster.filter { $0.group == "地煞七十二" }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        "梁山一百单八将的星号，取自《封神演义》第九十九回姜子牙所封的随斗部天罡三十六与地煞七十二。"
                        + "两书逐位对应，座次即封神榜上的次序。"
                    )
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Text("星名异写七处")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("天玄→天立 · 天健→天捷 · 天煞→天杀 · 地辅→地轴 · 地祐→地佑 · 地默→地然 · 地魂→地丑")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }

            section("天罡三十六", lords: tiangang)
            section("地煞七十二", lords: disha)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("一百单八将")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, lords: [FengshenLord]) -> some View {
        Section("\(title) · \(lords.count) 位") {
            ForEach(lords) { lord in
                if let shuihu = lord.shuihu {
                    row(lord, shuihu: shuihu)
                }
            }
        }
    }

    private func row(_ lord: FengshenLord, shuihu: ShuihuPeer) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(shuihu.rank)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(shuihu.star)
                        .font(.subheadline)
                    Text(shuihu.nickname)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shuihu.person)
                        .font(.subheadline)
                }
                Text(lord.title == shuihu.star
                     ? "封神 \(lord.title) \(lord.person)"
                     : "封神作 \(lord.title) · \(lord.person)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 6)
        }
        .padding(.vertical, 2)
    }
}
