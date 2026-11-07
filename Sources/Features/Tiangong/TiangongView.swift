import RealityKit
import SwiftUI
import TGReduxKit

struct TiangongView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @Bindable var session: TiangongSession

    @State private var environment: RealityViewEnvironment?
    @State private var probeLine: String?
    @State private var showsHistory = false

    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.016, blue: 0.038)
                .ignoresSafeArea()

            if let environment {
                reality(environment)
            }

            labelLayer

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if let selected = session.selected {
                    infoCard(selected)
                        .padding(.bottom, 10)
                }
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .task {
            environment = SpaceEnvironment.load()
            // 碰撞体与投影要等渲染就绪，立刻自检会全空。
            try? await Task.sleep(for: .seconds(1.2))
            probeLine = session.scene.verifyPicking()
        }
        .sheet(isPresented: $showsHistory) {
            TiangongHistorySheet()
        }
    }

    /// 部件名常驻在投影位置上。几何只到「示意」的程度，命名交给标签，
    /// 用户至少能回答「这是哪一段」——062 的降级方案。
    private var labelLayer: some View {
        // TimelineView 自己按 0.1s 刷新，不把锚点写回 @State——
        // 写回状态会让整个 body 重建，RealityView 跟着重算，画面会闪。
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let anchors = session.labelAnchors()
            ZStack {
                ForEach(TiangongModuleID.allCases) { id in
                    if let point = anchors[id] {
                        Text(id.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
                            .position(x: point.x, y: point.y - 24)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func reality(_ environment: RealityViewEnvironment) -> some View {
        RealityView { content in
            content.camera = .virtual
            content.environment = environment
            session.scene.build()
            content.add(session.scene.root)
            session.attach(content)
        } update: { _ in
            session.applyRig()
        }
        .coordinateSpace(name: "tiangong")
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .simultaneousGesture(selectGesture)
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                session.rotate(translation: value.translation)
            }
            .onEnded { _ in
                session.endDrag()
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                session.magnify(value.magnification)
            }
            .onEnded { _ in
                session.endMagnify()
            }
    }

    private var selectGesture: some Gesture {
        SpatialTapGesture(coordinateSpace: .named("tiangong"))
            .onEnded { value in
                session.pick(at: value.location)
            }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TiangongHistory.name)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(TiangongHistory.kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("1:\(Int(TiangongScale.ratio)) 展示 · 全长 \(formatted(TiangongModel.totalLength)) · 最大直径 \(formatted(TiangongModel.maxDiameter))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(TiangongHistory.facts.prefix(2).map { "\($0.label) \($0.value)" }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let probeLine {
                Text("pick · \(probeLine)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func infoCard(_ module: TiangongModuleID) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(module.title)
                    .font(.headline)
                Spacer(minLength: 6)
            }
            Text(module.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if TiangongDisassembly.isDismantlable(module) {
                Button(session.separated.contains(module) ? "装回" : "分离") {
                    session.toggleDisassembly(module)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
            Text("点空白处取消选择 · 神舟不参与拆装")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatted(_ meters: Float) -> String {
        let text = String(format: "%.2f", meters)
        let trimmed = text.hasSuffix("0") ? String(text.dropLast()) : text
        return trimmed + " m"
    }

    private var controlBar: some View {
        HStack(spacing: 18) {
            Button {
                session.resetView()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("重置视角")

            Button {
                store.dispatch(.route(.solarSystem))
            } label: {
                Image(systemName: "circle.hexagongrid")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("太阳系")

            Button {
                store.dispatch(.route(.sky))
            } label: {
                Image(systemName: "sparkles")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("星图")

            Button {
                showsHistory = true
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("史实")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct TiangongHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TiangongHistory.name)
                        .font(.title3.weight(.semibold))
                    Text(TiangongHistory.kind)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("关闭")
            }

            ForEach(TiangongHistory.facts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(fact.value)
                        .font(.subheadline)
                }
            }

            Text("史实条目与出处见 docs/research/realitykit-ios26-primary-sources.md 第 15 条。")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .preferredColorScheme(.dark)
    }
}
