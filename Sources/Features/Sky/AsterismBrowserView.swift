import SwiftUI

/// 星官目录：按四象二十八宿 + 其他星官浏览，点一行跳到天上。
struct AsterismBrowserView: View {
    var onLocate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [(title: String, items: [Asterism])] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = AsterismCatalog.all
        guard !trimmed.isEmpty else { return AsterismBrowse.sections(from: all) }
        let hits = all.filter { $0.name.contains(trimmed) }
        return hits.isEmpty ? [] : [("搜索「\(trimmed)」", hits)]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.items) { asterism in
                            Button {
                                onLocate(asterism.name)
                                dismiss()
                            } label: {
                                row(asterism)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(section.title)
                            Spacer()
                            Text("\(section.items.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("星官")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "星官名")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func row(_ asterism: Asterism) -> some View {
        let lord = FengshenInfo.lords(forAsterism: asterism.name).first
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asterism.name)
                    .font(.body)
                HStack(spacing: 6) {
                    Text("\(asterism.members.count) 星 · \(asterism.segmentCount) 线段")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let lord {
                        Text("\(lord.title) · \(lord.person)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "scope")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
