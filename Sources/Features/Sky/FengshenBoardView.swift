import SwiftUI

/// 封神星榜：按部浏览《封神演义》第九十九回的三百六十五位正神，
/// 其中有星官对应者可一键定位到星图。
struct FengshenBoardView: View {
    var onLocate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var path: [String]
    @State private var onlyLocatable = false

    init(
        initialDepartment: String? = nil,
        initialQuery: String = "",
        onLocate: @escaping (String) -> Void
    ) {
        self.onLocate = onLocate
        _query = State(initialValue: initialQuery)
        _path = State(initialValue: initialDepartment.map { [$0] } ?? [])
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

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                            FengshenRow(lord: lord, showsAffiliation: true, onLocate: onLocate)
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
            .navigationDestination(for: String.self) { department in
                FengshenDepartmentView(
                    department: department,
                    onlyLocatable: onlyLocatable,
                    onLocate: onLocate
                )
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
                        FengshenRow(lord: lord, showsAffiliation: false, onLocate: onLocate)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(department)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FengshenRow: View {
    var lord: FengshenLord
    var showsAffiliation: Bool
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
        .contentShape(Rectangle())
    }
}
