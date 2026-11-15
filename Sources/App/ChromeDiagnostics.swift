import SwiftUI
import TGReduxKit

struct ChromeDiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let settings = LaunchMode.diagnostics(environment: LaunchMode.environment())
        let lines = SessionLog.recentLines(40)

        return NavigationStack {
            List {
                Section("开关") {
                    diagnosticRow("帧率读数", settings.fpsHUD)
                    diagnosticRow("帧率日志", settings.perfLog)
                    diagnosticRow("拾取自检", settings.pickProbe)
                    diagnosticRow("坐标系状态", settings.coordinateStatus)
                }
                Section("启动参数") {
                    if settings.overrides.isEmpty {
                        Text("无")
                            .font(.system(size: ChromeTokens.captionSize, design: .monospaced))
                            .foregroundStyle(ChromeTokens.secondaryText)
                    } else {
                        ForEach(settings.overrides, id: \.self) { entry in
                            Text(entry)
                                .font(.system(size: ChromeTokens.captionSize, design: .monospaced))
                                .foregroundStyle(ChromeTokens.primaryText)
                        }
                    }
                }
                Section("运行日志（最近 40 行）") {
                    if lines.isEmpty {
                        Text("无")
                            .font(.system(size: ChromeTokens.captionSize, design: .monospaced))
                            .foregroundStyle(ChromeTokens.secondaryText)
                    } else {
                        ForEach(lines.indices, id: \.self) { index in
                            Text(lines[index])
                                .font(.system(size: ChromeTokens.captionSize, design: .monospaced))
                                .foregroundStyle(ChromeTokens.secondaryText)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func diagnosticRow(_ title: String, _ enabled: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: ChromeTokens.bodySize))
                .foregroundStyle(ChromeTokens.primaryText)
            Spacer()
            Text(enabled ? "开" : "关")
                .font(.system(size: ChromeTokens.captionSize, design: .monospaced))
                .foregroundStyle(enabled ? ChromeTokens.accent : ChromeTokens.secondaryText)
        }
    }
}
