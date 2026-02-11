//
//  DebugHangMonitor.swift
//  RealityRex
//
//  Detects potential main-thread stalls and logs warnings.
//

import Foundation
import QuartzCore

final class DebugHangMonitor {
    static let shared = DebugHangMonitor()

    private var displayLink: CADisplayLink?
    private var monitorTimer: DispatchSourceTimer?
    private var lastTick: CFTimeInterval = CACurrentMediaTime()
    private var started = false
    private var didReportHang = false

    private init() {}

    func start(threshold: TimeInterval = 2.0) {
        guard !started else { return }
        started = true

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        link.add(to: .main, forMode: .common)
        displayLink = link

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let now = CACurrentMediaTime()
            let delta = now - self.lastTick
            if delta >= threshold {
                if !self.didReportHang {
                    self.didReportHang = true
                    DebugLog.log("Warning: possible main-thread stall detected (\(String(format: "%.2f", delta))s)", category: "Perf")
                }
            } else {
                self.didReportHang = false
            }
        }
        monitorTimer = timer
        timer.resume()
    }

    @objc private func handleDisplayLink() {
        lastTick = CACurrentMediaTime()
    }
}
