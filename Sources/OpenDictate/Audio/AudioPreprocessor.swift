@preconcurrency import AVFoundation
import Foundation
import OpenDictateCore

enum AudioPreprocessor {
    static func prepare(audioURL: URL) async throws -> PreparedAudio {
        let timing = PhaseTiming(phase: "prepare")
        defer { timing.finish() }
        let originalDuration = try await duration(of: audioURL)
        guard originalDuration >= Config.minimumRecordingDuration else {
            throw OpenDictateError.recordingTooShort(actual: originalDuration, minimum: Config.minimumRecordingDuration)
        }

        let analysis = try analyze(audioURL: audioURL)
        AppLog.write(
            "Audio levels. peak=\(analysis.peakDb.formattedDb), avg=\(analysis.averageDb.formattedDb), threshold=\(Config.silenceThresholdDb.formattedDb)"
        )

        guard let speechRange = analysis.speechRange else {
            throw OpenDictateError.noSpeechDetected(peakDb: analysis.peakDb)
        }

        let plan = try TrimPlanner.plan(
            originalDuration: originalDuration,
            speechRange: speechRange,
            padding: Config.silencePadding,
            minimumDuration: Config.minimumRecordingDuration
        )

        guard plan.shouldExport else {
            return PreparedAudio(
                url: audioURL,
                uploadDuration: plan.uploadDuration
            )
        }

        let trimmedURL = try await exportTrimmedAudio(
            from: audioURL,
            start: plan.start,
            duration: plan.uploadDuration
        )

        return PreparedAudio(
            url: trimmedURL,
            uploadDuration: plan.uploadDuration
        )
    }

    private static func duration(of audioURL: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else {
            throw OpenDictateError.noAudioFile
        }
        return duration
    }

    /// Scans the recording in 50 ms windows: finds the speech span (windows above
    /// the silence threshold) and, regardless of the outcome, the peak and overall
    /// average level so callers can log them and distinguish "trimmed too hard"
    /// from "the microphone delivered (near) silence".
    static func analyze(audioURL: URL) throws -> AudioAnalysis {
        let timing = PhaseTiming(phase: "analyze")
        defer { timing.finish() }
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = max(1, Int(format.channelCount))
        let windowFrameCount = AVAudioFrameCount(max(1, Int(sampleRate * 0.05)))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: windowFrameCount) else {
            throw OpenDictateError.audioPreprocessingFailed("Could not allocate audio analysis buffer.")
        }

        var cursor: AVAudioFramePosition = 0
        var speech = SpeechRangeAccumulator(thresholdDb: Config.silenceThresholdDb)
        var peakDb = AudioLevels.floorDb
        var totalSquares: Float = 0
        var totalSamples = 0

        while file.framePosition < file.length {
            try Task.checkCancellation()
            let remaining = AVAudioFrameCount(min(Int64(windowFrameCount), file.length - file.framePosition))
            try file.read(into: buffer, frameCount: remaining)

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else {
                break
            }

            let window = windowPower(buffer: buffer, channelCount: channelCount, frameLength: frameLength)
            totalSquares += window.sumSquares
            totalSamples += window.count

            let db = AudioLevels.decibels(sumSquares: window.sumSquares, count: window.count)
            peakDb = max(peakDb, db)

            let start = Double(cursor) / sampleRate
            let end = Double(cursor + AVAudioFramePosition(frameLength)) / sampleRate
            speech.add(start: start, end: end, db: db)

            cursor += AVAudioFramePosition(frameLength)
        }

        return AudioAnalysis(
            speechRange: speech.range,
            peakDb: peakDb,
            averageDb: AudioLevels.decibels(sumSquares: totalSquares, count: totalSamples)
        )
    }

    private static func windowPower(
        buffer: AVAudioPCMBuffer,
        channelCount: Int,
        frameLength: Int
    ) -> (sumSquares: Float, count: Int) {
        guard let channelData = buffer.floatChannelData else {
            return (0, 0)
        }

        var sum: Float = 0
        var count = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
                count += 1
            }
        }

        return (sum, count)
    }

    static func exportTrimmedAudio(
        from inputURL: URL,
        start: TimeInterval,
        duration: TimeInterval
    ) async throws -> URL {
        let timing = PhaseTiming(phase: "export")
        defer { timing.finish() }
        let asset = AVURLAsset(url: inputURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("opendictate-trimmed-\(UUID().uuidString).m4a")

        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: outputURL) } }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw OpenDictateError.audioPreprocessingFailed("Could not create audio export session.")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        let exportBox = ExportSessionBox(exportSession)
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exportBox.session.exportAsynchronously {
                    switch exportBox.session.status {
                    case .completed:
                        continuation.resume()
                    case .failed, .cancelled:
                        continuation.resume(
                            throwing: OpenDictateError.audioPreprocessingFailed(
                                exportBox.session.error?.localizedDescription ?? "Audio export failed."
                            )
                        )
                    default:
                        continuation.resume(
                            throwing: OpenDictateError.audioPreprocessingFailed("Audio export ended unexpectedly.")
                        )
                    }
                }
            }
        } onCancel: {
            exportBox.session.cancelExport()
        }
        try Task.checkCancellation()
        completed = true
        return outputURL
    }
}
