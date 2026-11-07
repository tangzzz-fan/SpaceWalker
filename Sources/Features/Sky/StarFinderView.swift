import SwiftUI

struct StarFinderView: View {
    var stars: [Star]
    var onPick: (Star) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var constellation: StarFinder.ConstellationGroup?
    @State private var showsAllChinese = false

    private var results: [StarFinder.Hit] {
        StarFinder.search(stars, query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchSection
                } else if let constellation {
                    constellationSection(constellation)
                } else {
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
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "星名 / 中文名 / 星座")
        }
    }

    private var searchSection: some View {
        Section {
            if results.isEmpty {
                Text("没有匹配的星，试试「天狼」「北斗」「猎户」")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results, id: \.star.name) { hit in
                    row(hit)
                }
            }
        } header: {
            Text("搜索结果 \(results.count)")
        }
    }

    private func constellationSection(_ group: StarFinder.ConstellationGroup) -> some View {
        Section {
            ForEach(group.stars.prefix(40), id: \.name) { star in
                row(StarFinder.hit(for: star))
            }
        } header: {
            Text("\(group.name) · \(group.stars.count) 颗可选中")
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
}
