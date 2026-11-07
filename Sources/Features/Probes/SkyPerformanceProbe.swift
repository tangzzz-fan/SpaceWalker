import Foundation
import RealityKit
import SwiftUI

/// 星图帧率探针。和 AR 会话的 `ProbeRecorder` 分家，因为两者要量的东西不同：
/// AR 那边量锚点漂移，星图这边量「五层图形全开还跑不跑得动」。
///
/// 帧间隔取自 `SceneEvents.Update`——它每帧触发一次，显卡跟不上时触发频率跟着掉，
/// 所以是渲染负载的可用代理（`CADisplayLink` 反而会一直按屏幕刷新率回调，看不出掉帧）。
@MainActor
final class SkyPerformanceProbe {
    private let frames = FrameRateBox()
    private var subscription: EventSubscription?
    private var lastLog: TimeInterval?

    func attach(_ content: RealityViewCameraContent) {
        guard subscription == nil else { return }
        let frames = frames
        subscription = content.subscribe(to: SceneEvents.Update.self) { event in
            frames.append(event.deltaTime)
        }
    }

    /// 每秒调用一次刷新读数，每 5 秒写一行日志（日志里要能看出热状态怎么爬）。
    @discardableResult
    func tick(now: TimeInterval, layers: String) -> ProbeSummary {
        let sampler = frames.snapshot()
        var summary = ProbeSummary()
        summary.fps = sampler.averageFPS
        summary.minimumFPS = sampler.minimumFPS
        summary.hitches = sampler.hitchCount

        if lastLog == nil || now - (lastLog ?? 0) >= 5 {
            lastLog = now
            SessionLog.append(
                String(
                    format: "sky.perf avg=%.1f min=%.1f hitch=%.1f%% thermal=%@ layers=%@",
                    summary.fps,
                    summary.minimumFPS,
                    sampler.hitchRatio * 100,
                    Self.thermalLabel,
                    layers
                )
            )
        }
        return summary
    }

    static var thermalLabel: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
