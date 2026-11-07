import SwiftUI
import UIKit

struct PermissionView: View {
    let status: CameraPermissionState

    private var isRestricted: Bool {
        status == .restricted
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isRestricted ? "lock.slash" : "camera.metering.unknown")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(isRestricted ? PermissionCopy.restrictedTitle : PermissionCopy.deniedTitle)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(isRestricted ? PermissionCopy.restrictedBody : PermissionCopy.deniedBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if !isRestricted {
                Button(action: openSettings) {
                    Text(PermissionCopy.settingsButton)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(PermissionCopy.settingsButton)
                .accessibilityHint("打开系统设置，在 SpaceWalker 中开启相机权限")
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        isRestricted
            ? "\(PermissionCopy.restrictedTitle)。\(PermissionCopy.restrictedBody)"
            : "\(PermissionCopy.deniedTitle)。\(PermissionCopy.deniedBody)。\(PermissionCopy.settingsButton)"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct PermissionRequestingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(PermissionCopy.requestingTitle)
                .font(.headline)
            Text(PermissionCopy.requestingBody)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(PermissionCopy.requestingTitle)。\(PermissionCopy.requestingBody)")
    }
}
