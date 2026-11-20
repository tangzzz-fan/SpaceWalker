import SwiftUI
import TGReduxKit
import UIKit

enum ChromeTokens {
    static func adaptiveColor(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0 / 255, green: value.1 / 255, blue: value.2 / 255, alpha: 1)
        })
    }

    static func adaptiveInk(_ lightOpacity: CGFloat, _ darkOpacity: CGFloat) -> Color {
        Color(UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let ink: UIColor = dark ? .white : .black
            return ink.withAlphaComponent(dark ? darkOpacity : lightOpacity)
        })
    }

    static let background = adaptiveColor(light: (246, 247, 248), dark: (5, 7, 13))
    static let spaceBackground = adaptiveColor(light: (3, 4, 10), dark: (3, 4, 10))
    static let surface = background
    static let surface1 = adaptiveColor(light: (255, 255, 255), dark: (12, 16, 24))
    static let surface2 = adaptiveColor(light: (230, 233, 236), dark: (20, 25, 34))
    static let primaryText = adaptiveColor(light: (17, 21, 26), dark: (242, 244, 248))
    static let secondaryText = adaptiveColor(light: (105, 109, 113), dark: (154, 157, 162))
    static let tertiaryText = adaptiveColor(light: (128, 132, 136), dark: (130, 133, 138))
    static let disabledText = adaptiveColor(light: (160, 164, 168), dark: (100, 103, 108))
    static let hairline = adaptiveInk(0.12, 0.10)
    static let strongHairline = adaptiveInk(0.24, 0.18)
    static let accent = adaptiveColor(light: (138, 90, 22), dark: (232, 177, 92))
    static let accentPressed = adaptiveColor(light: (110, 71, 16), dark: (209, 154, 69))
    static let cyan = adaptiveColor(light: (47, 107, 234), dark: (111, 168, 200))

    static let captionSize: CGFloat = 11
    static let labelSize: CGFloat = 12
    static let bodySize: CGFloat = 12
    static let primarySize: CGFloat = 15
    static let titleSize: CGFloat = 20

    static let radiusPanel: CGFloat = 14
    static let radiusTag: CGFloat = 4
    static let contextRadius: CGFloat = 8
    static let indicatorSize: CGFloat = 4
    static let labelSpacing: CGFloat = 4
    static let tightPadding: CGFloat = 2
    static let compactPadding: CGFloat = 4
    static let horizontalPadding: CGFloat = 8
    static let cardPadding: CGFloat = 12
    static let edgePadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24

    static let statusBarHeight: CGFloat = 44
    static let rulerHeight: CGFloat = 56
    static let rulerLandscapeHeight: CGFloat = 48
    static let primaryDockHeight: CGFloat = 60
    static let contextDockHeight: CGFloat = 44
    static let buttonHeight: CGFloat = 44
    static let minTouchHeight: CGFloat = 44
    static let ladderNodeWidth: CGFloat = 100
    static let ladderNodeSpacing: CGFloat = 8
    static let ladderEdgeInset: CGFloat = 8
    static let ladderCurrentDot: CGFloat = 8
    static let ladderDefaultDot: CGFloat = 6
    static let ladderDisabledOpacity: Double = 0.3
    static let ladderDoubleTapWindow: Double = 0.5
    static let toastHeight: CGFloat = 32
    static let toastHoldDuration: Double = 2
    static let toastEnterDuration: Double = 0.28
    static let toastExitDuration: Double = 0.15
    static let rulerTrackHeight: CGFloat = 12
    static let rulerMarkerWidth: CGFloat = 2

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
                Button(store.state.chrome.theme == .dark ? "切换亮色" : "切换深色") {
                    store.dispatch(.chrome(.setTheme(
                        store.state.chrome.theme == .dark ? .light : .dark
                    )))
                }
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
                        .font(.system(size: ChromeTokens.labelSize, weight: control.isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: ChromeTokens.buttonHeight)
                        .foregroundStyle(
                            control.isSelected
                                ? ChromeTokens.accent
                                : (control.isEnabled ? ChromeTokens.secondaryText : ChromeTokens.disabledText)
                        )
                        .background(
                            control.isSelected ? ChromeTokens.surface2 : ChromeTokens.surface1.opacity(0.72)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ChromeTokens.contextRadius))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(control.title)
                .accessibilityAddTraits(control.isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, ChromeTokens.edgePadding)
        .frame(height: ChromeTokens.contextDockHeight)
    }
}

struct ChromeBottomBar: View {
    let actions: ChromeActionRegistry
    @Environment(Store<AppState, AppAction>.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ChromePrimaryDock(action: store.state.chrome.primaryAction, actions: actions)
            ChromeContextDock(controls: store.state.chrome.contextControls, actions: actions)
        }
        .background(ChromeTokens.surface1)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ChromeTokens.hairline)
                .frame(height: 1)
        }
    }
}
