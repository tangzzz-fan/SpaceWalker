import SwiftUI
import TGReduxKit

struct ContentView: View {
    @Environment(Store<AppState, AppAction>.self) private var store
    @State private var skySession = SkySession()
    @State private var tiangongSession = TiangongSession()

    var body: some View {
        Group {
            switch store.state.route {
            case .solarSystem:
                SpaceView()
            case .sky:
                SkyView(session: skySession)
            case .tiangong:
                TiangongView(session: tiangongSession)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChromeTabBar(tabs: store.state.chrome.tabs) { route in
                store.dispatch(.route(route))
            }
        }
    }
}

enum ChromeTokens {
    static let accent = Color(red: 232 / 255, green: 177 / 255, blue: 92 / 255)
    static let primaryText = Color(red: 242 / 255, green: 244 / 255, blue: 248 / 255)
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 173 / 255)
    static let surface = Color(red: 5 / 255, green: 7 / 255, blue: 13 / 255)
    static let hairline = Color.white.opacity(0.10)
    static let labelSize: CGFloat = 12
    static let indicatorSize: CGFloat = 4
    static let labelSpacing: CGFloat = 4
    static let horizontalPadding: CGFloat = 8
    static let minTouchHeight: CGFloat = 44
    static let barHeight: CGFloat = 56
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
        .frame(height: ChromeTokens.barHeight)
        .padding(.horizontal, ChromeTokens.horizontalPadding)
        .background(ChromeTokens.surface.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ChromeTokens.hairline)
                .frame(height: 1)
        }
    }
}
