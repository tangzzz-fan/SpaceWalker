import SwiftUI

struct ConstellationInfoView: View {
    var region: ConstellationRegion
    var stars: [Star]
    var onGuide: ((Star) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var fact: ConstellationFact? {
        ConstellationInfo.fact(for: region.abbreviation)
    }

    private var chineseStars: [StarFinder.Hit] {
        stars
            .filter {
                $0.constellation == region.abbreviation
                    && $0.isSelectable
                    && ChineseStarNames.chinese(for: $0.name) != nil
            }
            .sorted { $0.magnitude < $1.magnitude }
            .map(StarFinder.hit(for:))
    }

    private var selectableCount: Int {
        stars.filter { $0.constellation == region.abbreviation && $0.isSelectable }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    stats
                    if let fact {
                        section("西方来头", text: fact.westernLore)
                        section("中国星官", text: fact.chineseLore)
                    } else {
                        section("西方来头", text: "这个星座在本版本还没有收录释义，仅显示星表统计。")
                        section("中国星官", text: "暂无对应星官说明。")
                    }
                    if !fengshenEntries.isEmpty {
                        fengshenSection
                    }
                    if !chineseStars.isEmpty {
                        chineseStarList
                    }
                    if let brightest = region.brightest, let onGuide {
                        Button {
                            onGuide(brightest)
                            dismiss()
                        } label: {
                            Label("指路到 \(StarFinder.hit(for: brightest).chinese ?? brightest.name)", systemImage: "location.north.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(region.chineseName)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text(region.latinName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(region.abbreviation)
                    .font(.caption2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Text(seasonText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var seasonText: String {
        let distance = region.distance
        let proximity = distance > 0 ? String(format: " · 距最近成员星 %.1f°", distance) : ""
        return String(format: "星表内 %d 颗 · 最佳观测 %d 月", region.starCount, region.bestMonth) + proximity
    }

    private var stats: some View {
        HStack(spacing: 12) {
            metric(title: "最亮星", value: region.brightest.map { StarFinder.hit(for: $0).chinese ?? $0.name } ?? "—")
            metric(title: "视星等", value: region.brightest.map { String(format: "%.2f", $0.magnitude) } ?? "—")
            metric(title: "可选中", value: "\(selectableCount) 颗")
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fengshenEntries: [FengshenMansion] {
        var seen = Set<String>()
        var entries: [FengshenMansion] = []
        for hit in chineseStars {
            guard let mansion = StarDisplay.make(for: hit.star).asterism?.mansion,
                  let entry = FengshenInfo.entry(forMansion: mansion),
                  seen.insert(entry.mansion).inserted
            else { continue }
            entries.append(entry)
        }
        return entries
    }

    private var fengshenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("封神")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(fengshenEntries, id: \.mansion) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.lord)
                        .font(.callout)
                    Text(entry.person)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if let department = entry.department {
                        Text(department)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
            Text(FengshenInfo.sourceNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chineseStarList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("这里的星官")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowRow(spacing: 8) {
                ForEach(chineseStars, id: \.star.name) { hit in
                    Text(hit.chinese ?? hit.star.name)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}

struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
