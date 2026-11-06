import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("SpaceWalker")
                .font(.largeTitle)
            Text("工程骨架已就绪 · 等待 AR 交互方向确认")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
