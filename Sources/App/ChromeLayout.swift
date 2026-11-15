import SwiftUI
import TGReduxKit

enum ChromeTokens {
    static let background = Color(red: 5 / 255, green: 7 / 255, blue: 13 / 255)
    static let surface = background
    static let surface1 = Color(red: 12 / 255, green: 16 / 255, blue: 24 / 255)
    static let surface2 = Color(red: 20 / 255, green: 25 / 255, blue: 34 / 255)
    static let primaryText = Color(red: 242 / 255, green: 244 / 255, blue: 248 / 255)
    static let secondaryText = primaryText.opacity(0.62)
    static let tertiaryText = primaryText.opacity(0.52)
    static let disabledText = primaryText.opacity(0.38)
    static let hairline = Color.white.opacity(0.10)
    static let strongHairline = Color.white.opacity(0.18)
    static let accent = Color(red: 232 / 255, green: 177 / 255, blue: 92 / 255)
    static let accentPressed = Color(red: 209 / 255, green: 154 / 255, blue: 69 / 255)
    static let cyan = Color(red: 111 / 255, green: 168 / 255, blue: 200 / 255)

    static let captionSize: CGFloat = 11
    static let labelSize: CGFloat = 12
    static let bodySize: CGFloat = 13
    static let primarySize: CGFloat = 15
    static let titleSize: CGFloat = 20

    static let radiusPanel: CGFloat = 14
    static let radiusTag: CGFloat = 4
    static let indicatorSize: CGFloat = 4
    static let labelSpacing: CGFloat = 4
    static let edgePadding: CGFloat = 16
    static let horizontalPadding: CGFloat = 8
    static let tightPadding: CGFloat = 2

    static let statusBarHeight: CGFloat = 44
    static let primaryDockHeight: CGFloat = 60
    static let contextDockHeight: CGFloat = 44
    static let tabBarHeight: CGFloat = 56
    static let barHeight: CGFloat = tabBarHeight
    static let buttonHeight: CGFloat = 44
    static let minTouchHeight: CGFloat = 44

    static let cameraDuration: Double = 0.45
    static let panelDuration: Double = 0.28
    static let stateDuration: Double = 0.15
    static let diagnosticsHoldDuration: Double = 3
    static let infoCardMaxHeightRatio: Double = 0.32
    static let infoCardDismissDistance: CGFloat = 40
}

struct ChromeInfoCardBehavior: ViewModifier {
    let ratio: Double
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .frame(maxHeight: UIScreen.main.bounds.height * ratio)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        SessionLog.append(
                            String(format: "chrome.card.drag dy=%.0f", value.translation.height)
                        )
                        if value.translation.height > ChromeTokens.infoCardDismissDistance {
                            onDismiss()
                        }
                    }
            )
    }
}

final class ChromeActionRegistry {
    var primary: (@MainActor (ChromePrimaryID) -> Void)?
    var control: (@MainActor (ChromeControlID) -> Void)?
}

struct ChromeStatusBar: View {
    @Environment(Store<AppState, AppAction>.self) private var store

    let status: ChromeStatusLine
    let actions: ChromeActionRegistry

    var body: some View {
        HStack(alignment: .center, spacing: ChromeTokens.horizontalPadding) {
            VStack(alignment: .leading, spacing: ChromeTokens.tightPadding) {
                Text(status.title)
                    .font(.system(size: ChromeTokens.titleSize, weight: .semibold))
                    .foregroundStyle(ChromeTokens.primaryText)
                Text(status.detail)
                    .font(.system(size: ChromeTokens.captionSize))
                    .foregroundStyle(ChromeTokens.secondaryText)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: ChromeTokens.diagnosticsHoldDuration) {
                store.dispatch(.chrome(.toggleDiagnostics))
            }
            Spacer(minLength: 0)
            Menu {
                Button("素材来源") { actions.control?(.credits) }
                Button("史实与里程碑") { actions.control?(.history) }
                Text(versionLabel)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: ChromeTokens.bodySize, weight: .semibold))
                    .foregroundStyle(ChromeTokens.secondaryText)
                    .frame(width: ChromeTokens.buttonHeight, height: ChromeTokens.buttonHeight)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("更多")
        }
        .padding(.horizontal, ChromeTokens.edgePadding)
        .frame(height: ChromeTokens.statusBarHeight)
        .background(ChromeTokens.surface1.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChromeTokens.hairline)
                .frame(height: 1)
        }
    }

    private var versionLabel: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "星槎 v\(version)(\(build))"
    }
}

struct ChromePrimaryDock: View {
    let action: ChromePrimaryAction
    let actions: ChromeActionRegistry

    var body: some View {
        Button {
            actions.primary?(action.id)
        } label: {
            Text(action.title)
                .font(.system(size: ChromeTokens.primarySize, weight: .semibold))
                .foregroundStyle(action.isEnabled ? ChromeTokens.background : ChromeTokens.disabledText)
                .frame(maxWidth: .infinity, minHeight: ChromeTokens.buttonHeight)
                .background(action.isEnabled ? ChromeTokens.accent : ChromeTokens.surface2)
                .clipShape(RoundedRectangle(cornerRadius: ChromeTokens.radiusPanel))
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.title)
        .padding(.horizontal, ChromeTokens.edgePadding)
        .padding(.vertical, ChromeTokens.horizontalPadding)
        .frame(height: ChromeTokens.primaryDockHeight)
    }
}

struct ChromeContextDock: View {
    let controls: [ChromeControl]
    let actions: ChromeActionRegistry

    var body: some View {
        HStack(spacing: ChromeTokens.horizontalPadding) {
            ForEach(controls, id: \.id) { control in
                Button {
                    actions.control?(control.id)
                } label: {
                    Label(control.title, systemImage: control.symbol)
                        .font(.system(size: ChromeTokens.labelSize))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: ChromeTokens.buttonHeight)
                        .foregroundStyle(ChromeTokens.secondaryText)
                        .background(ChromeTokens.surface1.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: ChromeTokens.radiusTag + 4))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(control.title)
            }
        }
        .padding(.horizontal, ChromeTokens.edgePadding)
        .frame(height: ChromeTokens.contextDockHeight)
    }
}

struct ChromeTabBar: View {
    let tabs: [ChromeTab]
    let onSelect: (AppRoute) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.route) { tab in
                Button {
                    onSelect(tab.route)
                } label: {
                    VStack(spacing: ChromeTokens.labelSpacing) {
                        Text(tab.title)
                            .font(.system(size: ChromeTokens.labelSize, weight: tab.isSelected ? .semibold : .regular))
                        Circle()
                            .fill(tab.isSelected ? ChromeTokens.accent : Color.clear)
                            .frame(width: ChromeTokens.indicatorSize, height: ChromeTokens.indicatorSize)
                    }
                    .frame(maxWidth: .infinity, minHeight: ChromeTokens.minTouchHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(tab.isSelected ? ChromeTokens.primaryText : ChromeTokens.secondaryText)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab.isSelected ? [.isSelected] : [])
            }
        }
        .frame(height: ChromeTokens.tabBarHeight)
        .padding(.horizontal, ChromeTokens.horizontalPadding)
    }
}

struct ChromeBottomBar: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    let actions: ChromeActionRegistry

    var body: some View {
        VStack(spacing: 0) {
            ChromePrimaryDock(action: store.state.chrome.primaryAction, actions: actions)
            ChromeContextDock(controls: store.state.chrome.contextControls, actions: actions)
            ChromeTabBar(tabs: store.state.chrome.tabs) { route in
                store.dispatch(.route(route))
            }
        }
        .background(ChromeTokens.surface.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ChromeTokens.hairline)
                .frame(height: 1)
        }
    }
}
