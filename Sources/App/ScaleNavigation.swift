import Foundation
import RealityKit
import SwiftUI
import TGReduxKit

enum ScaleLadderAction {
    case none
    case navigate(ScaleLevel)
    case overview
}

enum ScaleLadder {
    static func tap(_ node: ChromeLadderNode, current: ScaleLevel) -> ScaleLadderAction {
        guard node.isEnabled else { return .none }
        if node.route == current { return .none }
        return .navigate(node.route)
    }

    static func doubleTap(_ node: ChromeLadderNode, current: ScaleLevel) -> ScaleLadderAction {
        node.route == current ? .overview : .none
    }
}

struct ScaleLadderView: View {
    let nodes: [ChromeLadderNode]
    let current: ScaleLevel
    let isLandscape: Bool
    let onSelect: (ScaleLevel) -> Void
    let onOverview: () -> Void

    @State private var lastTapRoute: ScaleLevel?
    @State private var lastTapAt: TimeInterval = 0

    var body: some View {
        Group {
            if isLandscape {
                HStack(spacing: ChromeTokens.ladderNodeSpacing) {
                    ForEach(nodes, id: \.route) { node in
                        nodeButton(node)
                    }
                }
            } else {
                VStack(spacing: ChromeTokens.ladderNodeSpacing) {
                    ForEach(nodes, id: \.route) { node in
                        nodeButton(node)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("尺度阶梯")
    }

    private func nodeButton(_ node: ChromeLadderNode) -> some View {
        Button {
            handleTap(node)
        } label: {
            HStack(spacing: ChromeTokens.compactPadding) {
                Spacer(minLength: 0)
                Text(node.title)
                    .font(.system(
                        size: ChromeTokens.labelSize,
                        weight: node.isSelected ? .semibold : .regular
                    ))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                dot(node)
            }
            .padding(.horizontal, ChromeTokens.compactPadding)
            .frame(
                width: isLandscape ? nil : ChromeTokens.ladderNodeWidth,
                height: ChromeTokens.minTouchHeight
            )
            .frame(maxWidth: isLandscape ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleLadderButtonStyle())
        .disabled(!node.isEnabled)
        .opacity(node.isEnabled ? 1 : ChromeTokens.ladderDisabledOpacity)
        .foregroundStyle(node.isSelected ? ChromeTokens.accent : ChromeTokens.secondaryText)
        .accessibilityLabel(node.title)
        .accessibilityValue(accessibilityState(node))
        .accessibilityAddTraits(node.isSelected ? [.isSelected] : [])
        .accessibilityAction(named: "回到本层全览") {
            if node.route == current { onOverview() }
        }
    }

    private func dot(_ node: ChromeLadderNode) -> some View {
        Group {
            switch node.state {
            case .current:
                Circle()
                    .fill(ChromeTokens.accent)
                    .frame(width: ChromeTokens.ladderCurrentDot, height: ChromeTokens.ladderCurrentDot)
            case .reachable:
                Circle()
                    .fill(ChromeTokens.secondaryText)
                    .frame(width: ChromeTokens.ladderDefaultDot, height: ChromeTokens.ladderDefaultDot)
            case .unreachable:
                Circle()
                    .stroke(ChromeTokens.secondaryText, lineWidth: 1)
                    .frame(width: ChromeTokens.ladderDefaultDot, height: ChromeTokens.ladderDefaultDot)
            }
        }
    }

    private func accessibilityState(_ node: ChromeLadderNode) -> String {
        switch node.state {
        case .current: "当前层"
        case .reachable: "可跳转"
        case .unreachable: "不可直达"
        }
    }

    private func handleTap(_ node: ChromeLadderNode) {
        let now = ProcessInfo.processInfo.systemUptime
        let isDouble = node.route == current
            && lastTapRoute == node.route
            && now - lastTapAt <= ChromeTokens.ladderDoubleTapWindow
        lastTapRoute = node.route
        lastTapAt = now
        if isDouble {
            lastTapRoute = nil
            if case .overview = ScaleLadder.doubleTap(node, current: current) {
                SessionLog.append("ladder.overview level=\(current)")
                onOverview()
            }
            return
        }
        if case .navigate(let target) = ScaleLadder.tap(node, current: current) {
            SessionLog.append("ladder.tap from=\(current) to=\(target)")
            onSelect(target)
        }
    }
}

private struct ScaleLadderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? ChromeTokens.surface2 : Color.clear,
                in: RoundedRectangle(cornerRadius: ChromeTokens.contextRadius)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.linear(duration: ChromeTokens.stateDuration), value: configuration.isPressed)
    }
}

struct ScaleRulerBar: View {
    let level: ScaleLevel
    let readingMeters: Double
    let isLandscape: Bool

    var body: some View {
        VStack(spacing: ChromeTokens.compactPadding) {
            HStack(alignment: .firstTextBaseline) {
                Text(level.rulerText)
                    .font(.system(size: ChromeTokens.captionSize))
                    .foregroundStyle(ChromeTokens.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: ChromeTokens.horizontalPadding)
                Text(ScaleRuler.readingText(meters: readingMeters))
                    .font(.system(size: ChromeTokens.captionSize).monospacedDigit())
                    .foregroundStyle(ChromeTokens.cyan)
                    .lineLimit(1)
                    .frame(minWidth: 72, alignment: .trailing)
                    .accessibilityLabel("当前尺度读数")
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                let range = ScaleRuler.trackRange(for: level)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ChromeTokens.strongHairline)
                        .frame(height: 1)
                    Capsule()
                        .fill(ChromeTokens.cyan.opacity(0.55))
                        .frame(
                            width: max(width * (range.upperBound - range.lowerBound), 2),
                            height: 3
                        )
                        .offset(x: width * range.lowerBound)
                    Rectangle()
                        .fill(ChromeTokens.cyan)
                        .frame(width: ChromeTokens.rulerMarkerWidth, height: ChromeTokens.rulerTrackHeight)
                        .offset(x: width * ScaleRuler.trackFraction(meters: readingMeters) - ChromeTokens.rulerMarkerWidth / 2)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: ChromeTokens.rulerTrackHeight)
            .accessibilityHidden(true)
            HStack {
                Text("10^0 m")
                Spacer()
                Text("10^20 m")
            }
            .font(.system(size: ChromeTokens.captionSize))
            .foregroundStyle(ChromeTokens.tertiaryText)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, ChromeTokens.edgePadding)
        .padding(.vertical, ChromeTokens.compactPadding)
        .frame(height: isLandscape ? ChromeTokens.rulerLandscapeHeight : ChromeTokens.rulerHeight)
        .background(ChromeTokens.surface1.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChromeTokens.hairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("尺度尺子，本层区间 \(level.rulerText)")
    }
}

struct AttitudeRestoreToast: View {
    let token: Int
    @State private var visible = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if visible {
                Text("已恢复姿态跟随")
                    .font(.system(size: ChromeTokens.captionSize))
                    .foregroundStyle(ChromeTokens.primaryText)
                    .padding(.horizontal, ChromeTokens.cardPadding)
                    .frame(height: ChromeTokens.toastHeight)
                    .background(ChromeTokens.surface1, in: RoundedRectangle(cornerRadius: ChromeTokens.contextRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: ChromeTokens.contextRadius)
                            .stroke(ChromeTokens.hairline, lineWidth: 1)
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityLabel("已恢复姿态跟随")
            }
        }
        .onChange(of: token) { _, value in
            guard value > 0 else { return }
            show()
        }
        .onAppear {
            if token > 0 { show() }
        }
    }

    private func show() {
        hideTask?.cancel()
        withAnimation(.easeOut(duration: ChromeTokens.toastEnterDuration)) {
            visible = true
        }
        SessionLog.append("chrome.attitudeToast show")
        let hold = LaunchMode.attitudeToastHoldDuration(
            environment: ProcessInfo.processInfo.environment
        ) ?? ChromeTokens.toastHoldDuration
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: ChromeTokens.toastExitDuration)) {
                visible = false
            }
            SessionLog.append("chrome.attitudeToast hide")
        }
    }
}