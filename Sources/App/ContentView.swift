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
            VStack(alignment: .trailing, spacing: 0) {
                ChromeVersionBadge()
                ChromeTabBar(tabs: store.state.chrome.tabs) { route in
                    store.dispatch(.route(route))
                }
            }
            .background(ChromeTokens.surface.opacity(0.92))
        }
        .sheet(isPresented: diagnosticsBinding) {
            ChromeDiagnosticsSheet()
        }
    }

    private var diagnosticsBinding: Binding<Bool> {
        Binding(
            get: { store.state.chrome.diagnosticsVisible },
            set: { presented in
                guard !presented, store.state.chrome.diagnosticsVisible else { return }
                store.dispatch(.chrome(.toggleDiagnostics))
            }
        )
    }
}

enum ChromeTokens {
    static let accent = Color(red: 232 / 255, green: 177 / 255, blue: 92 / 255)
    static let primaryText = Color(red: 242 / 255, green: 244 / 255, blue: 248 / 255)
    static let secondaryText = Color(red: 158 / 255, green: 163 / 255, blue: 173 / 255)
    static let surface = Color(red: 5 / 255, green: 7 / 255, blue: 13 / 255)
    static let hairline = Color.white.opacity(0.10)
    static let labelSize: CGFloat = 12
    static let captionSize: CGFloat = 11
    static let bodySize: CGFloat = 13
    static let indicatorSize: CGFloat = 4
    static let labelSpacing: CGFloat = 4
    static let horizontalPadding: CGFloat = 8
    static let tightPadding: CGFloat = 2
    static let minTouchHeight: CGFloat = 44
    static let barHeight: CGFloat = 56
    static let diagnosticsHoldDuration: Double = 3
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
