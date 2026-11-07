import SwiftUI

struct TonightTourView: View {
    var tour: TonightTour
    var onPick: (SkyGroup) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tour.headline)
                        .font(.title3.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 2)

                    ForEach(tour.stops) { stop in
                        card(stop)
                    }

                    Text("按此刻高度与该星座最亮星综合排序。点任一站会关闭本页并直接指路。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .navigationTitle("今夜导览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func card(_ stop: TonightStop) -> some View {
        Button {
            onPick(stop.pick.group)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(stop.order)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(stop.pick.group.title)
                            .font(.headline)
                        Spacer(minLength: 6)
                        Text(stop.pick.altitudeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(stop.tip)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("最佳观赏 \(stop.pick.seasonText) · \(stop.pick.group.memberCount) 颗可选")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "location.north.line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
