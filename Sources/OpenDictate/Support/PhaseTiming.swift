import Foundation

struct PhaseTiming {
    private let start = ContinuousClock.now
    let phase: String

    func finish() {
        let duration = start.duration(to: .now)
        let milliseconds = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
        AppLog.write("Timing phase=\(phase), milliseconds=\(String(format: "%.2f", milliseconds))")
    }
}
